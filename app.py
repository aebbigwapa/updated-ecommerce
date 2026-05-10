from flask import Flask, Response
from flask_cors import CORS
from dotenv import load_dotenv
import os

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
    CORS(app, resources={
        r"/api/*": {
            "origins": ["*"],  # Configure appropriately for production
            "methods": ["GET", "POST", "PUT", "PATCH", "DELETE", "OPTIONS"],
            "allow_headers": ["Content-Type", "Authorization", "X-Auth-Token"],
            "supports_credentials": True
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

    # Register API error handlers for Flutter compatibility
    from routes.api.api_helpers import register_api_error_handlers
    register_api_error_handlers(app)

    # Init CSRF AFTER blueprints are registered
    init_csrf(app)

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

    # Note: /login and /logout are handled by auth_bp blueprint
    # No need to duplicate them here
    
    return app

# For backward compatibility
if __name__ == '__main__':
    app = create_app()
    app.run(debug=True, host='0.0.0.0', port=5000, threaded=True)