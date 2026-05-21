from flask import Blueprint, render_template, request, jsonify, session, redirect, url_for
from models.message_model import MessageModel

messages_bp = Blueprint('messages', __name__, url_prefix='/messages')
msg_model = MessageModel()


def _login_required(f):
    from functools import wraps
    @wraps(f)
    def decorated(*args, **kwargs):
        if 'user' not in session:
            return redirect(url_for('auth.login'))
        return f(*args, **kwargs)
    return decorated


def _current_user():
    return session.get('user', {})


def _is_admin():
    return _current_user().get('role') == 'admin'


def _notify_chat_recipient(sender, receiver_id, conversation_id, order_id=None, snippet=None):
    """Create a chat notification for the receiver when a new message arrives."""
    if not receiver_id or not conversation_id:
        return

    from models.notification_model import NotificationModel
    notification_model = NotificationModel()

    title_name = sender.get('first_name') or sender.get('last_name') or 'New message'
    title = f'New message from {title_name}' if title_name else 'New message'
    message = (snippet or 'You have received a new message.').strip()
    action_url = f'/messages?conversation_id={conversation_id}'

    try:
        notification_model.create(
            user_id=receiver_id,
            notif_type='chat',
            title=title,
            message=message,
            action_url=action_url,
            data_payload={'conversation_id': conversation_id, 'order_id': order_id}
        )
    except Exception as e:
        print(f'Error creating chat notification: {e}')


# ── Pages ─────────────────────────────────────────────────────

@messages_bp.route('/')
@_login_required
def inbox():
    return render_template('messages/chat.html')


@messages_bp.route('/admin')
@_login_required
def admin_inbox():
    if not _is_admin():
        return redirect(url_for('messages.inbox'))
    return render_template('messages/admin_chat.html')


# ── API: Conversations ────────────────────────────────────────

@messages_bp.route('/api/conversations', methods=['GET'])
@_login_required
def api_conversations():
    user = _current_user()
    if _is_admin():
        convs = msg_model.get_all_conversations()
    else:
        convs = msg_model.get_conversations_for_user(user['id'])
    return jsonify(convs)


@messages_bp.route('/api/conversations/start', methods=['POST'])
@_login_required
def api_start_conversation():
    user = _current_user()
    data = request.get_json() or {}
    other_id = data.get('user_id')
    order_id = data.get('order_id')
    if not other_id:
        return jsonify({'error': 'user_id is required'}), 400
    if other_id == user['id']:
        return jsonify({'error': 'Cannot message yourself'}), 400
    conv = msg_model.get_or_create_conversation(user['id'], other_id, order_id)
    if not conv:
        return jsonify({'error': 'Failed to create conversation'}), 500
    # Enrich with participant data for admin panel
    if _is_admin():
        all_ids = list({conv['participant_1'], conv['participant_2']})
        users_res = msg_model.supabase.table('users').select(
            'id, first_name, last_name, role, email, profile_picture'
        ).in_('id', all_ids).execute()
        users_map = {u['id']: u for u in (users_res.data or [])}
        conv['participant_1_data'] = users_map.get(conv['participant_1'])
        conv['participant_2_data'] = users_map.get(conv['participant_2'])
    return jsonify(conv)


@messages_bp.route('/api/conversations/find', methods=['GET'])
@_login_required
def api_find_conversation():
    """Find existing conversation between current user and another user, optionally by order_id."""
    user = _current_user()
    other_id = request.args.get('user_id')
    order_id = request.args.get('order_id')
    if not other_id:
        return jsonify({'error': 'user_id is required'}), 400
    if other_id == user['id']:
        return jsonify({'error': 'Cannot message yourself'}), 400
    
    p1, p2 = sorted([user['id'], other_id])
    query = msg_model.supabase.table('conversations').select('*').eq('participant_1', p1).eq('participant_2', p2)
    if order_id:
        query = query.eq('order_id', order_id)
    else:
        query = query.is_('order_id', 'null')
    result = query.limit(1).execute()
    return jsonify(result.data[0] if result.data else None)


@messages_bp.route('/api/conversations/<conv_id>/messages', methods=['GET'])
@_login_required
def api_get_messages(conv_id):
    user = _current_user()
    if not msg_model.user_can_access(conv_id, user['id'], _is_admin()):
        return jsonify({'error': 'Unauthorized'}), 403
    after_id = request.args.get('after')
    if after_id:
        msgs = msg_model.get_new_messages(conv_id, after_id)
    else:
        msgs = msg_model.get_messages(conv_id)
    msg_model.mark_read(conv_id, user['id'])
    return jsonify(msgs)


@messages_bp.route('/api/conversations/<conv_id>/messages', methods=['POST'])
@_login_required
def api_send_message(conv_id):
    user = _current_user()
    if not msg_model.user_can_access(conv_id, user['id'], _is_admin()):
        return jsonify({'error': 'Unauthorized'}), 403
    data = request.get_json() or {}
    content = (data.get('content') or '').strip()
    if not content:
        return jsonify({'error': 'Message content is required'}), 400

    conv = msg_model.get_conversation_by_id(conv_id)
    if not conv:
        return jsonify({'error': 'Conversation not found'}), 404

    # Determine receiver: the other participant
    sender_id = user['id']
    receiver_id = conv['participant_2'] if conv['participant_1'] == sender_id else conv['participant_1']

    msg = msg_model.send_message(conv_id, sender_id, receiver_id, content, data.get('attachment_url'))
    if not msg:
        return jsonify({'error': 'Failed to send message'}), 500

    _notify_chat_recipient(user, receiver_id, conv_id, conv.get('order_id'), content)
    return jsonify(msg), 201


@messages_bp.route('/api/conversations/<conv_id>/read', methods=['POST'])
@_login_required
def api_mark_read(conv_id):
    user = _current_user()
    if not msg_model.user_can_access(conv_id, user['id'], _is_admin()):
        return jsonify({'error': 'Unauthorized'}), 403
    msg_model.mark_read(conv_id, user['id'])
    return jsonify({'success': True})


# ── API: Unread count ─────────────────────────────────────────

@messages_bp.route('/api/unread-count', methods=['GET'])
@_login_required
def api_unread_count():
    count = msg_model.get_unread_count(_current_user()['id'])
    return jsonify({'count': count})


# ── API: Quick message (any role → any role per order) ────────

QUICK_MSG = "Thank you for your order! We are currently processing your items. We will update you once it is ready for pickup."

@messages_bp.route('/api/quick-message', methods=['POST'])
@_login_required
def api_quick_message():
    """Start or reuse a conversation and optionally send the welcome auto-message.
    Body: { other_id, order_id, send_auto: bool }
    Returns: { conversation_id, already_sent, message?, other_user: {first_name, last_name} }
    
    Note: This is a generic endpoint for any role-to-role messaging.
    """
    user = _current_user()
    data = request.get_json() or {}
    other_id = data.get('other_id') or data.get('buyer_id')  # Support both old and new param names
    order_id = data.get('order_id')
    send_auto = data.get('send_auto', False)

    if not other_id or not order_id:
        return jsonify({'error': 'other_id and order_id are required'}), 400
    if other_id == user['id']:
        return jsonify({'error': 'Cannot message yourself'}), 400

    conv = msg_model.get_or_create_conversation(user['id'], other_id, order_id)
    if not conv:
        return jsonify({'error': 'Failed to create conversation'}), 500

    conv_id = conv['id']
    already_sent = msg_model.auto_message_sent(conv_id, user['id'])

    sent_msg = None
    if send_auto and not already_sent:
        sender_id   = user['id']
        receiver_id = other_id
        sent_msg = msg_model.send_message(conv_id, sender_id, receiver_id, QUICK_MSG)
        if sent_msg:
            _notify_chat_recipient(user, receiver_id, conv_id, order_id, QUICK_MSG)

    # Fetch other user info for display
    other_user = msg_model.supabase.table('users').select('id, first_name, last_name, profile_picture, role').eq('id', other_id).single().execute()
    other_data = other_user.data if other_user.data else {}

    return jsonify({
        'conversation_id': conv_id,
        'already_sent':    already_sent,
        'message':         sent_msg,
        'other_user':           other_data,
    })


# ── Flutter Bearer-token endpoints (no session required) ─────

def _bearer_user():
    from routes.api.api_helpers import get_current_user
    return get_current_user()


def _enrich_conv_with_store_name(conv):
    """Attach store_name to other_user if they are a seller."""
    other = conv.get('other_user') or {}
    if other.get('role') == 'seller':
        try:
            app_res = msg_model.supabase.table('applications') \
                .select('store_name').eq('user_id', other['id']) \
                .eq('role', 'seller').limit(1).execute()
            if app_res.data:
                other['store_name'] = app_res.data[0].get('store_name', '')
                conv['other_user'] = other
        except Exception:
            pass
    return conv


@messages_bp.route('/api/flutter/conversations', methods=['GET'])
def flutter_conversations():
    user = _bearer_user()
    if not user:
        return jsonify({'error': 'Unauthorized'}), 401
    is_admin = user.get('role') == 'admin'
    if is_admin:
        convs = msg_model.get_all_conversations()
    else:
        convs = msg_model.get_conversations_for_user(user['id'])
        convs = [_enrich_conv_with_store_name(c) for c in convs]
    return jsonify(convs)


@messages_bp.route('/api/flutter/conversations/start', methods=['POST'])
def flutter_start_conversation():
    """Flutter: start or find a conversation. Body: {other_id, order_id?}"""
    user = _bearer_user()
    if not user:
        return jsonify({'error': 'Unauthorized'}), 401
    data = request.get_json() or {}
    other_id = data.get('other_id') or data.get('user_id')
    order_id = data.get('order_id')
    if not other_id:
        return jsonify({'error': 'other_id is required'}), 400
    if other_id == user['id']:
        return jsonify({'error': 'Cannot message yourself'}), 400
    conv = msg_model.get_or_create_conversation(user['id'], other_id, order_id)
    if not conv:
        return jsonify({'error': 'Failed to create conversation'}), 500
    conv = _enrich_conv_with_store_name(conv)
    return jsonify(conv), 201


@messages_bp.route('/api/flutter/unread-count', methods=['GET'])
def flutter_unread_count():
    """Flutter: total unread message count for the current user."""
    user = _bearer_user()
    if not user:
        return jsonify({'error': 'Unauthorized'}), 401
    count = msg_model.get_unread_count(user['id'])
    return jsonify({'count': count})


@messages_bp.route('/api/flutter/conversations/<conv_id>/messages', methods=['GET'])
def flutter_get_messages(conv_id):
    user = _bearer_user()
    if not user:
        return jsonify({'error': 'Unauthorized'}), 401
    if not msg_model.user_can_access(conv_id, user['id'], user.get('role') == 'admin'):
        return jsonify({'error': 'Forbidden'}), 403
    after_id = request.args.get('after')
    msgs = msg_model.get_new_messages(conv_id, after_id) if after_id else msg_model.get_messages(conv_id)
    msg_model.mark_read(conv_id, user['id'])
    return jsonify(msgs)


@messages_bp.route('/api/flutter/conversations/<conv_id>/messages', methods=['POST'])
def flutter_send_message(conv_id):
    user = _bearer_user()
    if not user:
        return jsonify({'error': 'Unauthorized'}), 401
    if not msg_model.user_can_access(conv_id, user['id'], user.get('role') == 'admin'):
        return jsonify({'error': 'Forbidden'}), 403
    data = request.get_json() or {}
    content = (data.get('content') or '').strip()
    if not content:
        return jsonify({'error': 'Message content is required'}), 400
    conv = msg_model.get_conversation_by_id(conv_id)
    if not conv:
        return jsonify({'error': 'Conversation not found'}), 404
    sender_id = user['id']
    receiver_id = conv['participant_2'] if conv['participant_1'] == sender_id else conv['participant_1']
    msg = msg_model.send_message(conv_id, sender_id, receiver_id, content, data.get('attachment_url'))
    if not msg:
        return jsonify({'error': 'Failed to send message'}), 500
    # Attach sender info so Flutter can display it immediately
    msg['sender'] = {
        'id': user['id'],
        'role': user.get('role', ''),
        'first_name': user.get('first_name', ''),
        'last_name': user.get('last_name', ''),
    }
    _notify_chat_recipient(user, receiver_id, conv_id, conv.get('order_id'), content)
    return jsonify(msg), 201


# ── Flutter-ready aliases ─────────────────────────────────────

@messages_bp.route('/api/messages', methods=['GET'])
@_login_required
def api_messages_list():
    """Flutter: GET /messages/api/messages?conversation_id=xxx"""
    conv_id = request.args.get('conversation_id')
    if not conv_id:
        return jsonify({'error': 'conversation_id required'}), 400
    return api_get_messages(conv_id)


@messages_bp.route('/api/messages', methods=['POST'])
@_login_required
def api_messages_send():
    """Flutter: POST /messages/api/messages"""
    data = request.get_json() or {}
    conv_id = data.get('conversation_id')
    if not conv_id:
        return jsonify({'error': 'conversation_id required'}), 400
    return api_send_message(conv_id)


@messages_bp.route('/api/admin-user-id', methods=['GET'])
def api_get_admin_user_id():
    """Get admin user ID for support chat"""
    from models.user_model import UserModel
    user_model = UserModel()
    try:
        admin = user_model.supabase.table('users').select('id').eq('role', 'admin').limit(1).execute()
        if admin.data:
            return jsonify({'admin_id': admin.data[0]['id']})
        return jsonify({'error': 'No admin user found'}), 404
    except Exception as e:
        return jsonify({'error': str(e)}), 500


@messages_bp.route('/api/users', methods=['GET'])
@_login_required
def api_list_users_for_admin():
    """Session-based: admin only. List users for new conversation modal.
    Optional ?role=buyer|seller|rider&search=name"""
    if not _is_admin():
        return jsonify({'error': 'Forbidden'}), 403
    role_filter = request.args.get('role', '').strip()
    search = request.args.get('search', '').strip().lower()
    try:
        query = msg_model.supabase.table('users').select(
            'id, first_name, last_name, role, email, profile_picture'
        ).neq('role', 'admin').order('first_name')
        if role_filter in ('buyer', 'seller', 'rider'):
            query = query.eq('role', role_filter)
        result = query.limit(200).execute()
        users = result.data or []
        if search:
            users = [u for u in users if search in
                     f"{u.get('first_name','')} {u.get('last_name','')} {u.get('email','')}".lower()]
        return jsonify(users)
    except Exception as e:
        return jsonify({'error': str(e)}), 500


@messages_bp.route('/api/flutter/users', methods=['GET'])
def flutter_list_users():
    """Admin only: list all users for starting new conversations.
    Optional ?role=buyer|seller|rider&search=name"""
    user = _bearer_user()
    if not user or user.get('role') != 'admin':
        return jsonify({'error': 'Forbidden'}), 403
    role_filter = request.args.get('role', '').strip()
    search = request.args.get('search', '').strip().lower()
    try:
        query = msg_model.supabase.table('users').select(
            'id, first_name, last_name, role, email, profile_picture'
        ).neq('role', 'admin').order('first_name')
        if role_filter in ('buyer', 'seller', 'rider'):
            query = query.eq('role', role_filter)
        result = query.limit(100).execute()
        users = result.data or []
        if search:
            users = [u for u in users if search in
                     f"{u.get('first_name','')} {u.get('last_name','')} {u.get('email','')}".lower()]
        # Attach store names for sellers
        seller_ids = [u['id'] for u in users if u.get('role') == 'seller']
        if seller_ids:
            apps = msg_model.supabase.table('applications').select('user_id, store_name') \
                .in_('user_id', seller_ids).eq('role', 'seller').execute()
            store_map = {a['user_id']: a.get('store_name', '') for a in (apps.data or [])}
            for u in users:
                if u.get('role') == 'seller':
                    u['store_name'] = store_map.get(u['id'], '')
        return jsonify(users)
    except Exception as e:
        return jsonify({'error': str(e)}), 500
