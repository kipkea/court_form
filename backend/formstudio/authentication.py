import jwt
from django.conf import settings
from rest_framework.authentication import BaseAuthentication
from rest_framework.exceptions import AuthenticationFailed
from budget.models import User
from portal.models import PortalApp, UserAppPermission


def check_is_form_admin(user, token_payload=None):
    if not user or not user.is_authenticated:
        return False
    if user.username in getattr(settings, 'SUPER_USERNAMES', ['root', 'beebee']):
        return True
    if user.is_superuser or getattr(user, 'role', '') == 'admin' or getattr(user, 'is_court_admin', False):
        return True
    if token_payload and token_payload.get('app_role') == 'admin':
        return True
    app_codes = getattr(settings, 'FORM_APP_CODES', ['court_form', 'court_form_local'])
    perm = UserAppPermission.objects.filter(
        user=user,
        app__code__in=app_codes,
        can_access=True
    ).first()
    if perm and str(perm.app_role).lower() == 'admin':
        return True
    return False


class FormStudioJWTAuthentication(BaseAuthentication):
    """
    รองรับการยืนยันตัวตนด้วย:
    1. Authorization: Bearer <token>
    2. Query parameter: ?token=<token> (สำหรับเปิดหน้าต่าง Print PDF หรือดาวน์โหลดโดยตรง)
    """
    def authenticate(self, request):
        raw_token = None
        auth_header = request.headers.get('Authorization', '')
        if auth_header.startswith('Bearer '):
            raw_token = auth_header.split(' ', 1)[1].strip()
        elif request.query_params.get('token'):
            raw_token = request.query_params.get('token', '').strip()

        if not raw_token:
            return None

        payload = None
        for secret in (settings.SECRET_KEY, getattr(settings, 'PORTAL_SECRET_KEY', '')):
            if not secret:
                continue
            try:
                payload = jwt.decode(raw_token, secret, algorithms=['HS256'])
                break
            except jwt.ExpiredSignatureError:
                raise AuthenticationFailed('เซสชันหมดอายุ กรุณาเข้าสู่ระบบผ่าน Portal อีกครั้ง')
            except Exception:
                continue

        if not payload:
            raise AuthenticationFailed('Token ไม่ถูกต้อง')

        user = None
        user_id = payload.get('user_id')
        username = payload.get('username')
        if user_id:
            user = User.objects.filter(id=user_id).first()
        if not user and username:
            user = User.objects.filter(username=username).first()

        if not user or not user.is_active:
            raise AuthenticationFailed('ไม่พบผู้ใช้งานหรือบัญชีถูกระงับ')

        request.token_payload = payload
        request.is_form_admin = check_is_form_admin(user, payload)
        return (user, raw_token)
