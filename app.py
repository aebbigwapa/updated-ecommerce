from flask import Flask, Response, session
from flask_cors import CORS
from dotenv import load_dotenv
import os
import time

load_dotenv()

# Minimal 1x1 transparent favicon (ICO format header + minimal data)
FAVICON_DATA = (
    b'\x00\x00\x01\x00\x01\x00\x01\x01\x00\x00\x01\x00\x18\x00'
    b'\x04\x00\x00\x00\x16\x00\x00\x00\x10\x00\x00\x00\x02\x00'
    b'\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00'
    b'\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00'
    b'\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00'
    b'\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00'
    b'\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00'
    b'\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00'
    b'\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00'
    b'\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00'
    b'\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00'
    b'\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00'
    b'\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00'
    b'\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00'
    b'\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00'
    b'\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00'
)


def create_app():
    app = Flask(__name__)
    app.secret_key = os.getenv('SECRET_KEY')

    # ── Favicon route ──────────────────────────────────────────
    @app.route('/favicon.ico')
    def favicon():
        return Response(FAVICON_DATA, mimetype='image/x-icon')

    # ── CORS configuration for Flutter mobile app ────────────────────────
    allowed_origins = os.getenv('ALLOWED_ORIGINS', '').split(',') if os.getenv('ALLOWED_ORIGINS') else ["*"]
    CORS(app, resources={
        r"/api/*": {
            "origins": allowed_origins,
            "methods": ["GET", "POST", "PUT", "PATCH", "DELETE", "OPTIONS"],
            "allow_headers": ["Content-Type", "Authorization", "X-Auth-Token"],
            "supports_credentials": len(allowed_origins) > 0 and allowed_origins != ["*"]
        }
    })

    # ── Security configuration ────────────────────────────────
    from security import configure_session, init_csrf
    configure_session(app)
    
    # Supabase client (lazy-loaded in services)
    app.config['SUPABASE_URL'] = os.getenv('SUPABASE_URL')
    app.config['SUPABASE_SERVICE_ROLE_KEY'] = os.getenv('SUPABASE_SERVICE_ROLE_KEY')
    
    # reCAPTCHA configuration
    app.config['RECAPTCHA_SITE_KEY'] = os.getenv('RECAPTCHA_SITE_KEY')
    
    # Register blueprints
    from routes.auth_routes import auth_bp
    from routes.admin_routes import admin_bp
    from routes.seller_routes import seller_bp
    from routes.buyer_routes import buyer_bp
    from routes.rider_routes import rider_bp
    from routes.messages_routes import messages_bp
    
    # Register API blueprints (Flutter-compatible)
    from routes.api.auth_api import auth_api_bp
    from routes.api.products_api import products_api_bp
    from routes.api.cart_api import cart_api_bp
    from routes.api.orders_api import orders_api_bp
    from routes.api.seller_api import seller_api_bp
    from routes.api.admin_api import admin_api_bp as mobile_admin_api_bp
    from routes.api.rider_api import rider_api_bp
    from routes.api.messages_api import messages_api_bp
    from routes.api.shipping_api import shipping_api_bp
    
    app.register_blueprint(auth_bp)
    app.register_blueprint(admin_bp, url_prefix='/admin')
    app.register_blueprint(seller_bp, url_prefix='/seller')
    app.register_blueprint(buyer_bp, url_prefix='/buyer')
    app.register_blueprint(rider_bp, url_prefix='/rider')
    app.register_blueprint(messages_bp)
    
    # Register API routes with /api prefix
    app.register_blueprint(auth_api_bp,     url_prefix='/api')
    app.register_blueprint(products_api_bp,  url_prefix='/api')
    app.register_blueprint(cart_api_bp,      url_prefix='/api')
    app.register_blueprint(orders_api_bp,    url_prefix='/api')
    app.register_blueprint(seller_api_bp,    url_prefix='/api')
    app.register_blueprint(mobile_admin_api_bp, url_prefix='/api')
    app.register_blueprint(rider_api_bp,        url_prefix='/api')
    app.register_blueprint(messages_api_bp,     url_prefix='/api')
    app.register_blueprint(shipping_api_bp,     url_prefix='/api')

    # Register API error handlers for Flutter compatibility
    from routes.api.api_helpers import register_api_error_handlers
    register_api_error_handlers(app)

    # Init CSRF AFTER blueprints are registered
    init_csrf(app)

    @app.after_request
    def _no_cache_protected_routes(response):
        from flask import request as req
        protected = ('/admin', '/seller', '/buyer', '/rider')
        if req.path.startswith(protected):
            response.headers['Cache-Control'] = 'no-store, no-cache, must-revalidate, private'
            response.headers['Pragma'] = 'no-cache'
            response.headers['Expires'] = '0'
        return response

    @app.before_request
    def _refresh_browser_session_activity():
        user = session.get('user') or {}
        user_id = user.get('id') or session.get('user_id')
        role = user.get('role') or session.get('user_role')
        session_id = session.get('audit_session_id')
        now = time.time()
        if user_id and role and session_id and now - session.get('_audit_last_touch', 0) >= 300:
            from security import log_session
            log_session(user_id, role, 'activity', session_id)
            session['_audit_last_touch'] = now

    # Ensure csrf_token is always available in templates even if init_csrf fails
    @app.context_processor
    def inject_csrf():
        from security import generate_csrf_token
        return {'csrf_token': generate_csrf_token}
    
    # Main routes (static pages)
    @app.route('/')
    def index():
        from models.product_model import ProductModel
        product_model = ProductModel()
        products = product_model.get_all_active()
        return __import__('flask').render_template('buyer/index.html', products=products)

    # Public info pages (no login required)
    @app.route('/about')
    def about():
        return __import__('flask').render_template('buyer/about.html')

    @app.route('/terms')
    def terms():
        return __import__('flask').render_template('buyer/terms.html')

    @app.route('/privacy')
    def privacy():
        return __import__('flask').render_template('buyer/privacy.html')

    @app.route('/help')
    def help_support():
        return __import__('flask').render_template('buyer/help.html')

    # Note: /login and /logout are handled by auth_bp blueprint
    # No need to duplicate them here

    # ── Auto-backup every 12 hours ────────────────────────────
    _start_auto_backup(app)

    return app


def _start_auto_backup(app):
    try:
        from apscheduler.schedulers.background import BackgroundScheduler
        scheduler = BackgroundScheduler(daemon=True)
        scheduler.add_job(
            func=_run_auto_backup,
            trigger='interval',
            hours=12,
            id='auto_backup',
            replace_existing=True,
        )
        scheduler.start()
        print('[AutoBackup] Scheduler started — every 12 hours')
    except Exception as e:
        print(f'[AutoBackup] Failed to start scheduler: {e}')


def _run_auto_backup():
    try:
        from services.backup_service import BackupService
        result = BackupService().create_backup(triggered_by='auto', notes='Scheduled every 12 hours')
        print(f'[AutoBackup] {"✅ Success" if result["success"] else "❌ Failed"} — {result["file_name"]} ({result["file_size_kb"]} KB, {result["total_rows"]} rows)')
    except Exception as e:
        print(f'[AutoBackup] Error: {e}')

# For backward compatibility
if __name__ == '__main__':
    app = create_app()
    debug = os.getenv('FLASK_DEBUG', 'false').lower() == 'true'
    host = os.getenv('FLASK_HOST', '0.0.0.0')
    app.run(debug=debug, host=host, port=5000, threaded=True)