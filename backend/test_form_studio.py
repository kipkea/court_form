import os
import sys
import jwt
from datetime import datetime, timedelta
from pathlib import Path

current_dir = Path(__file__).resolve().parent
sys.path.insert(0, str(current_dir))
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'config.settings')

import django
django.setup()

from django.conf import settings
from rest_framework.test import APIClient
from budget.models import User


def run_smoke_tests():
    client = APIClient()

    # 1. Test Health Check
    res = client.get('/api/form/health/')
    assert res.status_code == 200, f"Health check failed: {res.content}"
    print("[PASS] 1. Health Check OK")

    # 2. Test SSO Ticket Verification (Simulated from Court Central Portal)
    admin_user = User.objects.filter(username__in=['beebee', 'root']).first() or User.objects.filter(is_active=True).first()
    assert admin_user is not None, "No active user found in cdmc_system"

    sso_payload = {
        'user_id': admin_user.id,
        'username': admin_user.username,
        'role': 'admin',
        'target_app': 'court_form',
        'exp': datetime.utcnow() + timedelta(minutes=5),
        'iss': 'cdmc_portal',
    }
    sso_ticket = jwt.encode(sso_payload, settings.PORTAL_SECRET_KEY, algorithm='HS256')
    res = client.post('/api/form/auth/sso-verify/', {'sso_ticket': sso_ticket}, format='json')
    assert res.status_code == 200, f"SSO Verify failed: {res.content}"
    token = res.data['token']
    client.credentials(HTTP_AUTHORIZATION=f'Bearer {token}')
    print(f"[PASS] 2. SSO Ticket Verified for {admin_user.username} (is_form_admin={res.data['user']['is_form_admin']})")

    # 3. Test Paper Sizes & Templates
    res_sizes = client.get('/api/form/paper-sizes/')
    assert res_sizes.status_code == 200 and len(res_sizes.data) >= 8
    res_tpls = client.get('/api/form/templates/')
    assert res_tpls.status_code == 200 and len(res_tpls.data) >= 5
    cheque_tpl = next(t for t in res_tpls.data if t['code'] == 'cheque_standard')
    print(f"[PASS] 3. Loaded {len(res_sizes.data)} Paper Presets & {len(res_tpls.data)} Routine Templates")

    # 4. Test Data Sources (portal_users & courts)
    res_users_ds = client.get('/api/form/data-sources/portal_users/records/')
    assert res_users_ds.status_code == 200 and res_users_ds.data['enabled'] is True
    res_courts_ds = client.get('/api/form/data-sources/courts/records/')
    assert res_courts_ds.status_code == 200 and res_courts_ds.data['enabled'] is True
    print(f"[PASS] 4. Data Sources OK (Users: {len(res_users_ds.data['records'])}, Courts: {len(res_courts_ds.data['records'])})")

    # 5. Test Render PDF & PNG + Print Audit Log creation
    render_payload = {
        'action_type': 'PRINT',
        'template_id': cheque_tpl['id'],
        'template_code': cheque_tpl['code'],
        'template_name': cheque_tpl['name'],
        'width_mm': cheque_tpl['width_mm'],
        'height_mm': cheque_tpl['height_mm'],
        'fields_schema': cheque_tpl['fields_schema'],
        'values': {
            'ac_payee': 'true',
            'cheque_date': '28102569',
            'payee_name': 'นางสาวสมหญิง รักความยุติธรรม',
            'strike_bearer': 'true',
            'amount_num': '25400.50',
            'amount_text': '',
        },
        'print_background': False,
        'offset_x_mm': 0.5,
        'offset_y_mm': -0.5,
        'data_source_used': 'portal_users',
    }
    res_pdf = client.post('/api/form/render/', render_payload, format='json')
    assert res_pdf.status_code == 200 and res_pdf.data['success'] is True
    assert len(res_pdf.data['file_base64']) > 500
    print(f"[PASS] 5. PDF Render & Print Log Recorded (Log ID: {res_pdf.data['log_id']})")

    render_payload['action_type'] = 'EXPORT_PNG'
    res_png = client.post('/api/form/render/', render_payload, format='json')
    assert res_png.status_code == 200 and res_png.data['mime_type'] == 'image/png'
    print(f"[PASS] 6. 300 DPI PNG Image Export Recorded (Log ID: {res_png.data['log_id']})")

    # 6. Test Admin Audit Logs Query
    res_logs = client.get('/api/form/print-logs/')
    assert res_logs.status_code == 200 and len(res_logs.data) >= 2
    first_log = res_logs.data[0]
    print(f"[PASS] 7. Admin Print Audit Log Verified: {first_log['summary_text']}")


if __name__ == '__main__':
    run_smoke_tests()
