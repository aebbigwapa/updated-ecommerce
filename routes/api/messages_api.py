"""
/api/messages/* — Flutter messaging endpoints (Bearer token auth).

Mirrors the web /messages/api/flutter/* endpoints but under the cleaner
/api/messages/* path so Flutter can use a single base URL.
"""

from flask import Blueprint, request, jsonify
from routes.api.api_helpers import get_current_user, api_response, api_error
from models.message_model import MessageModel

messages_api_bp = Blueprint('messages_api', __name__)
_msg = MessageModel()


def _user():
    return get_current_user()


def _enrich_store_name(conv):
    """Attach store_name to other_user when they are a seller."""
    other = conv.get('other_user') or {}
    if other.get('role') == 'seller':
        try:
            res = _msg.supabase.table('applications') \
                .select('store_name').eq('user_id', other['id']) \
                .eq('role', 'seller').limit(1).execute()
            if res.data:
                other['store_name'] = res.data[0].get('store_name', '')
                conv['other_user'] = other
        except Exception:
            pass
    return conv


@messages_api_bp.get('/messages/conversations')
def list_conversations():
    user = _user()
    if not user:
        return api_error('Unauthorized', status=401)
    is_admin = user.get('role') == 'admin'
    if is_admin:
        convs = _msg.get_all_conversations()
    else:
        convs = _msg.get_conversations_for_user(user['id'])
        convs = [_enrich_store_name(c) for c in convs]
    return api_response(data=convs, message='OK')


@messages_api_bp.post('/messages/conversations')
def start_conversation():
    """Start or find a conversation. Body: {other_id, order_id?}"""
    user = _user()
    if not user:
        return api_error('Unauthorized', status=401)
    data = request.get_json() or {}
    other_id = data.get('other_id') or data.get('user_id')
    order_id = data.get('order_id')
    if not other_id:
        return api_error('other_id is required', status=400)
    if other_id == user['id']:
        return api_error('Cannot message yourself', status=400)
    conv = _msg.get_or_create_conversation(user['id'], other_id, order_id)
    if not conv:
        return api_error('Failed to create conversation', status=500)
    conv = _enrich_store_name(conv)
    return api_response(data=conv, message='OK', status=201)


@messages_api_bp.get('/messages/conversations/<conv_id>/messages')
def get_messages(conv_id):
    user = _user()
    if not user:
        return api_error('Unauthorized', status=401)
    if not _msg.user_can_access(conv_id, user['id'], user.get('role') == 'admin'):
        return api_error('Forbidden', status=403)
    after_id = request.args.get('after')
    msgs = _msg.get_new_messages(conv_id, after_id) if after_id else _msg.get_messages(conv_id)
    _msg.mark_read(conv_id, user['id'])
    return api_response(data=msgs, message='OK')


@messages_api_bp.post('/messages/conversations/<conv_id>/messages')
def send_message(conv_id):
    user = _user()
    if not user:
        return api_error('Unauthorized', status=401)
    if not _msg.user_can_access(conv_id, user['id'], user.get('role') == 'admin'):
        return api_error('Forbidden', status=403)
    data = request.get_json() or {}
    content = (data.get('content') or '').strip()
    if not content:
        return api_error('Message content is required', status=400)
    conv = _msg.get_conversation_by_id(conv_id)
    if not conv:
        return api_error('Conversation not found', status=404)
    sender_id = user['id']
    receiver_id = conv['participant_2'] if conv['participant_1'] == sender_id else conv['participant_1']
    msg = _msg.send_message(conv_id, sender_id, receiver_id, content, data.get('attachment_url'))
    if not msg:
        return api_error('Failed to send message', status=500)
    # Attach sender info for immediate display
    msg['sender'] = {
        'id': user['id'],
        'role': user.get('role', ''),
        'first_name': user.get('first_name', ''),
        'last_name': user.get('last_name', ''),
    }
    # Notify recipient
    from routes.messages_routes import _notify_chat_recipient
    _notify_chat_recipient(user, receiver_id, conv_id, conv.get('order_id'), content)
    return api_response(data=msg, message='OK', status=201)


@messages_api_bp.post('/messages/conversations/<conv_id>/read')
def mark_read(conv_id):
    user = _user()
    if not user:
        return api_error('Unauthorized', status=401)
    if not _msg.user_can_access(conv_id, user['id'], user.get('role') == 'admin'):
        return api_error('Forbidden', status=403)
    _msg.mark_read(conv_id, user['id'])
    return api_response(data={}, message='OK')


@messages_api_bp.get('/messages/unread-count')
def unread_count():
    user = _user()
    if not user:
        return api_error('Unauthorized', status=401)
    count = _msg.get_unread_count(user['id'])
    return api_response(data={'count': count}, message='OK')
