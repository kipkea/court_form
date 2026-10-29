import base64
import uuid
import jwt
from datetime import datetime, timedelta
from django.conf import settings
from django.db.models import Q, Sum, Count
from django.http import HttpResponse
from django.utils import timezone
from rest_framework import viewsets, views, status, permissions
from rest_framework.decorators import action
from rest_framework.parsers import MultiPartParser, FormParser, JSONParser
from rest_framework.response import Response

from budget.models import User
from portal.models import PortalApp, UserAppPermission
from formstudio.authentication import check_is_form_admin
from formstudio.models import (
    PaperSizePreset,
    DataSourceConfig,
    FormTemplate,
    PrinterOffsetProfile,
    FormPrintLog,
)
from formstudio.serializers import (
    PaperSizePresetSerializer,
    DataSourceConfigSerializer,
    FormTemplateListSerializer,
    FormTemplateDetailSerializer,
    PrinterOffsetProfileSerializer,
    FormPrintLogSerializer,
)
from formstudio.services.render_service import (
    render_form_pdf_bytes,
    render_form_png_bytes,
    number_to_thai_baht_text,
    format_thai_date,
    resolve_field_display_value,
)
from formstudio.services.datasource_service import (
    DEFAULT_DATA_SOURCES,
    fetch_datasource_records,
    parse_tabular_file,
)


def get_client_ip(request):
    xff = request.META.get('HTTP_X_FORWARDED_FOR')
    if xff:
        return xff.split(',')[0].strip()
    return request.META.get('REMOTE_ADDR', '')


def get_portal_url(request):
    host = (request.get_host() or 'localhost').split(':')[0]
    if host in ('127.0.0.1', 'localhost'):
        return 'http://localhost:8888/'
    return f'http://{host}:8888/'


def build_user_response_dict(user, app_role=None, is_form_admin=False):
    court_name = user.court.name if getattr(user, 'court', None) else 'ศาลแขวงเชียงดาว'
    court_code = user.court.code if getattr(user, 'court', None) else 'CDMC'
    book_number = user.court.book_number if getattr(user, 'court', None) else ''
    return {
        'id': user.id,
        'user_id': user.id,
        'username': user.username,
        'title': getattr(user, 'title', '') or '',
        'first_name': user.first_name or '',
        'last_name': user.last_name or '',
        'display_name': user.display_name,
        'department': getattr(user, 'department', '') or 'ส่วนงานกลาง',
        'position': getattr(user, 'position', '') or 'เจ้าหน้าที่ศาล',
        'phone_number': getattr(user, 'phone_number', '') or '',
        'email': user.email or '',
        'court_id': getattr(user, 'court_id', None),
        'court_name': court_name,
        'court_code': court_code,
        'book_number': book_number,
        'role': getattr(user, 'role', 'user'),
        'app_role': app_role or ('admin' if is_form_admin else 'user'),
        'is_superuser': bool(user.is_superuser),
        'is_court_admin': bool(getattr(user, 'is_court_admin', False)),
        'is_form_admin': bool(is_form_admin),
    }


def issue_local_jwt(user, is_form_admin=False):
    app_role = 'admin' if is_form_admin else 'user'
    exp = datetime.utcnow() + timedelta(days=7)
    payload = {
        'user_id': user.id,
        'username': user.username,
        'role': getattr(user, 'role', 'user'),
        'app_role': app_role,
        'is_form_admin': bool(is_form_admin),
        'exp': exp,
        'iss': 'court_form_studio',
    }
    return jwt.encode(payload, settings.SECRET_KEY, algorithm='HS256')


class IsFormAdminPermission(permissions.BasePermission):
    """
    อนุญาตให้เฉพาะ Admin เท่านั้นที่สร้าง/แก้ไข/ลบแม่แบบงานประจำ และจัดการ Data Source หรือดู Log ทั้งหมดได้
    """
    def has_permission(self, request, view):
        if not request.user or not request.user.is_authenticated:
            return False
        return bool(getattr(request, 'is_form_admin', False) or check_is_form_admin(request.user))


# ==============================================================================
# 1. Health & SSO Authentication Views
# ==============================================================================
class HealthCheckView(views.APIView):
    permission_classes = [permissions.AllowAny]

    def get(self, request):
        return Response({
            'status': 'ok',
            'app': 'court_form',
            'name': 'ระบบออกแบบและจัดพิมพ์แบบฟอร์มอัจฉริยะ (Court Smart Form & Print Studio)',
            'port': 8007,
            'timestamp': timezone.now().isoformat(),
        })


class SSOVerifyView(views.APIView):
    """
    POST /api/form/auth/sso-verify/
    รับ sso_ticket จาก Court Central Portal (Port 8888) และออก Local JWT Token
    """
    authentication_classes = []
    permission_classes = [permissions.AllowAny]

    def post(self, request):
        ticket = request.data.get('sso_ticket') or request.data.get('ticket')
        if not ticket:
            return Response({'error': 'กรุณาระบุ sso_ticket'}, status=status.HTTP_400_BAD_REQUEST)

        secret_key = getattr(settings, 'PORTAL_SECRET_KEY', 'portal-sso-shared-secret-key-cdmc-2026')
        try:
            payload = jwt.decode(ticket, secret_key, algorithms=['HS256'])
        except jwt.ExpiredSignatureError:
            return Response(
                {'error': 'SSO Ticket หมดอายุแล้ว กรุณาเข้าใช้งานผ่านหน้า Portal อีกครั้ง'},
                status=status.HTTP_401_UNAUTHORIZED
            )
        except Exception as e:
            return Response(
                {'error': f'SSO Ticket ไม่ถูกต้อง: {str(e)}'},
                status=status.HTTP_401_UNAUTHORIZED
            )

        user = None
        if payload.get('user_id'):
            user = User.objects.select_related('court').filter(id=payload.get('user_id')).first()
        if not user and payload.get('username'):
            user = User.objects.select_related('court').filter(username=payload.get('username')).first()

        if not user or not user.is_active:
            return Response(
                {'error': 'ไม่พบบัญชีผู้ใช้งานหรือบัญชีถูกระงับ'},
                status=status.HTTP_403_FORBIDDEN
            )

        ticket_role = str(payload.get('role', '')).lower()
        is_admin = check_is_form_admin(user, {'app_role': ticket_role})
        access_token = issue_local_jwt(user, is_form_admin=is_admin)

        return Response({
            'valid': True,
            'token': access_token,
            'user': build_user_response_dict(user, app_role=ticket_role, is_form_admin=is_admin),
            'portal_url': get_portal_url(request),
        })


class DirectLoginView(views.APIView):
    """
    POST /api/form/auth/login/
    รองรับการเข้าสู่ระบบด้วยบัญชี Portal หรือสลับบทบาททดสอบ (เมื่อเปิดใช้งานโดยตรง)
    """
    authentication_classes = []
    permission_classes = [permissions.AllowAny]

    def post(self, request):
        username = (request.data.get('username') or '').strip()
        password = (request.data.get('password') or '').strip()

        if not username or not password:
            return Response({'error': 'กรุณากรอกชื่อผู้ใช้และรหัสผ่าน'}, status=status.HTTP_400_BAD_REQUEST)

        user = User.objects.select_related('court').filter(username=username).first()
        if not user or not user.check_password(password):
            return Response({'error': 'ชื่อผู้ใช้หรือรหัสผ่านไม่ถูกต้อง'}, status=status.HTTP_401_UNAUTHORIZED)
        if not user.is_active:
            return Response({'error': 'บัญชีผู้ใช้นี้ถูกระงับการใช้งาน'}, status=status.HTTP_403_FORBIDDEN)

        is_admin = check_is_form_admin(user)
        access_token = issue_local_jwt(user, is_form_admin=is_admin)

        return Response({
            'valid': True,
            'token': access_token,
            'user': build_user_response_dict(user, is_form_admin=is_admin),
            'portal_url': get_portal_url(request),
        })


class CurrentUserView(views.APIView):
    permission_classes = [permissions.IsAuthenticated]

    def get(self, request):
        user = request.user
        is_admin = getattr(request, 'is_form_admin', False) or check_is_form_admin(user)
        return Response({
            'user': build_user_response_dict(user, is_form_admin=is_admin),
            'portal_url': get_portal_url(request),
        })


# ==============================================================================
# 2. Paper Size Presets & Form Templates (Admin Manage, All Users Read/Use)
# ==============================================================================
class PaperSizePresetViewSet(viewsets.ModelViewSet):
    queryset = PaperSizePreset.objects.filter(is_active=True).order_by('sort_order', 'id')
    serializer_class = PaperSizePresetSerializer

    def get_permissions(self):
        if self.action in ('list', 'retrieve'):
            return [permissions.IsAuthenticated()]
        return [IsFormAdminPermission()]


class FormTemplateViewSet(viewsets.ModelViewSet):
    queryset = FormTemplate.objects.all().order_by('sort_order', 'id')

    def get_permissions(self):
        if self.action in ('list', 'retrieve'):
            return [permissions.IsAuthenticated()]
        return [IsFormAdminPermission()]

    def get_queryset(self):
        qs = FormTemplate.objects.all().order_by('sort_order', 'id')
        is_admin = getattr(self.request, 'is_form_admin', False) or check_is_form_admin(self.request.user)
        if not is_admin:
            qs = qs.filter(is_active=True)
        category = self.request.query_params.get('category', '').strip()
        if category and category != 'ALL':
            qs = qs.filter(category=category)
        return qs

    def get_serializer_class(self):
        if self.action == 'list':
            return FormTemplateListSerializer
        return FormTemplateDetailSerializer

    def perform_create(self, serializer):
        code = serializer.validated_data.get('code')
        if not code:
            code = f"tpl_{uuid.uuid4().hex[:8]}"
        serializer.save(code=code, created_by=self.request.user)

    @action(detail=True, methods=['post'], permission_classes=[IsFormAdminPermission])
    def duplicate(self, request, pk=None):
        orig = self.get_object()
        new_code = f"{orig.code}_copy_{uuid.uuid4().hex[:4]}"
        new_name = request.data.get('name') or f"{orig.name} (สำเนา)"
        copy_obj = FormTemplate.objects.create(
            code=new_code,
            name=new_name,
            category=orig.category,
            description=orig.description,
            paper_preset=orig.paper_preset,
            width_mm=orig.width_mm,
            height_mm=orig.height_mm,
            orientation=orig.orientation,
            background_image=orig.background_image,
            print_background=orig.print_background,
            grid_size_mm=orig.grid_size_mm,
            default_offset_x_mm=orig.default_offset_x_mm,
            default_offset_y_mm=orig.default_offset_y_mm,
            allowed_data_source=orig.allowed_data_source,
            fields_schema=list(orig.fields_schema) if isinstance(orig.fields_schema, list) else [],
            is_active=True,
            sort_order=orig.sort_order + 1,
            created_by=request.user,
        )
        return Response(FormTemplateDetailSerializer(copy_obj).data, status=status.HTTP_201_CREATED)


# ==============================================================================
# 3. Data Sources (Filtered & Permitted by Admin) & Batch File Upload
# ==============================================================================
class DataSourceConfigViewSet(viewsets.ModelViewSet):
    queryset = DataSourceConfig.objects.all().order_by('id')
    serializer_class = DataSourceConfigSerializer

    def get_permissions(self):
        if self.action in ('list', 'retrieve', 'records'):
            return [permissions.IsAuthenticated()]
        return [IsFormAdminPermission()]

    def list(self, request, *args, **kwargs):
        configs = DataSourceConfig.objects.all().order_by('id')
        is_admin = getattr(request, 'is_form_admin', False) or check_is_form_admin(request.user)
        if not is_admin:
            configs = configs.filter(is_enabled=True)
        data = DataSourceConfigSerializer(configs, many=True).data
        for item in data:
            meta = DEFAULT_DATA_SOURCES.get(item['source_code'], {})
            item['available_fields'] = meta.get('exposed_fields', [])
        return Response(data)

    @action(detail=False, methods=['get'], url_path=r'(?P<source_code>[^/.]+)/records')
    def records(self, request, source_code=None):
        search = request.query_params.get('search', '').strip()
        result = fetch_datasource_records(source_code=source_code, request_user=request.user, search=search)
        if not result.get('enabled', False):
            return Response(result, status=status.HTTP_403_FORBIDDEN)
        return Response(result)


class BatchFileParseView(views.APIView):
    """
    POST /api/form/batch/parse-file/
    อัปโหลดไฟล์ CSV หรือ Excel (.xlsx) เพื่อแปลงเป็นรายการข้อมูลสำหรับสั่งพิมพ์ต่อเนื่องหลายแผ่น (Mail Merge)
    """
    permission_classes = [permissions.IsAuthenticated]
    parser_classes = [MultiPartParser, FormParser]

    def post(self, request):
        file_obj = request.FILES.get('file')
        if not file_obj:
            return Response({'error': 'กรุณาเลือกไฟล์ .csv หรือ .xlsx'}, status=status.HTTP_400_BAD_REQUEST)
        try:
            parsed = parse_tabular_file(file_obj)
            return Response({
                'filename': file_obj.name,
                'columns': parsed.get('columns', []),
                'rows': parsed.get('rows', []),
                'row_count': len(parsed.get('rows', [])),
            })
        except Exception as e:
            return Response({'error': f'ไม่สามารถอ่านไฟล์ได้: {str(e)}'}, status=status.HTTP_400_BAD_REQUEST)


# ==============================================================================
# 4. Printer Offset Profiles & Text Conversion Helpers
# ==============================================================================
class PrinterOffsetProfileViewSet(viewsets.ModelViewSet):
    serializer_class = PrinterOffsetProfileSerializer
    permission_classes = [permissions.IsAuthenticated]

    def get_queryset(self):
        return PrinterOffsetProfile.objects.filter(
            Q(is_shared=True) | Q(user=self.request.user)
        ).order_by('-is_shared', 'name')

    def perform_create(self, serializer):
        is_admin = getattr(self.request, 'is_form_admin', False) or check_is_form_admin(self.request.user)
        is_shared = bool(serializer.validated_data.get('is_shared', False)) if is_admin else False
        serializer.save(user=self.request.user, is_shared=is_shared)


class TextHelperView(views.APIView):
    """
    POST /api/form/helpers/convert/
    แปลงตัวเลขเป็นตัวอักษรภาษาไทย (bahttext) และวันที่ไทย
    """
    permission_classes = [permissions.IsAuthenticated]

    def post(self, request):
        amount = request.data.get('amount')
        date_val = request.data.get('date')
        date_fmt = request.data.get('date_format', 'full')
        wrap_brackets = bool(request.data.get('wrap_brackets', False))
        thai_digits = bool(request.data.get('thai_digits', False))

        return Response({
            'bahttext': number_to_thai_baht_text(amount, wrap_brackets=wrap_brackets) if amount is not None else '',
            'date_thai': format_thai_date(date_val, fmt=date_fmt, thai_digits=thai_digits) if date_val else '',
        })


# ==============================================================================
# 5. Render PDF / PNG & Record Print Audit Log
# ==============================================================================
class RenderAndPrintView(views.APIView):
    """
    POST /api/form/render/
    เรนเดอร์แบบพิมพ์เป็นไฟล์ PDF หรือรูปภาพ PNG (300 DPI)
    พร้อมบันทึก Audit Log ว่าใครพิมพ์อะไรไปเมื่อไหร่

    รองรับทั้ง:
    1. ผู้ใช้งานทั่วไปที่ล็อกอินผ่านระบบเว็บ/แอป
    2. ระบบอื่นในหน่วยงาน (Inter-System / Microservice) เรียกใช้ผ่าน X-Portal-Secret
       โดยระบุ template_code และ values มาประกอบร่างเป็น PDF ส่งกลับไปใช้งานได้ทันที
    """
    permission_classes = [permissions.AllowAny]
    parser_classes = [JSONParser]

    def post(self, request):
        data = request.data or {}

        # 1. การตรวจสอบสิทธิ์: ล็อกอินปกติ หรือ เรียกข้ามระบบด้วย X-Portal-Secret
        shared_secret = getattr(settings, 'PORTAL_SECRET_KEY', 'portal-sso-shared-secret-key-cdmc-2026')
        header_secret = request.headers.get('X-Portal-Secret') or request.headers.get('X-Service-Key')
        body_secret = data.get('portal_secret') or data.get('service_key')
        is_service_call = (header_secret == shared_secret) or (body_secret == shared_secret)

        user = request.user
        if not (user and user.is_authenticated):
            if is_service_call:
                target_user = data.get('username') or ''
                user = User.objects.filter(username=target_user).first() if target_user else None
                if not user:
                    user = User.objects.filter(is_superuser=True).first() or User.objects.first()
            else:
                return Response(
                    {'error': 'กรุณาเข้าสู่ระบบ หรือแนบ Header X-Portal-Secret สำหรับการเรียกใช้งานข้ามระบบ'},
                    status=status.HTTP_401_UNAUTHORIZED,
                )

        action_type = str(data.get('action_type', 'EXPORT_PDF' if is_service_call else 'PRINT')).upper()
        if action_type not in ('PRINT', 'EXPORT_PDF', 'EXPORT_PNG', 'BATCH_PDF', 'PREVIEW_PNG'):
            action_type = 'EXPORT_PDF' if is_service_call else 'PRINT'

        template_id = data.get('template_id')
        template_code_in = data.get('template_code')
        tpl = None
        if template_id:
            tpl = FormTemplate.objects.filter(id=template_id).first()
        if not tpl and template_code_in:
            tpl = FormTemplate.objects.filter(code=template_code_in).first()

        template_name = data.get('template_name') or (tpl.name if tpl else 'แบบพิมพ์กำหนดเอง')
        template_code = tpl.code if tpl else (template_code_in or 'custom')

        width_mm = float(data.get('width_mm') or (tpl.width_mm if tpl else 210.0))
        height_mm = float(data.get('height_mm') or (tpl.height_mm if tpl else 297.0))
        paper_size_label = data.get('paper_size_label') or (f"{tpl.paper_preset} ({width_mm:g}×{height_mm:g} มม.)" if tpl else f"{width_mm:g}×{height_mm:g} มม.")

        fields_schema = data.get('fields_schema')
        if not isinstance(fields_schema, list) or not fields_schema:
            fields_schema = tpl.fields_schema if tpl else []

        values = data.get('values') if isinstance(data.get('values'), dict) else {}
        records = data.get('records') if isinstance(data.get('records'), list) else [values]
        if not records:
            records = [values]

        background_image = data.get('background_image')
        if background_image is None and tpl:
            background_image = tpl.background_image
        print_background = bool(data.get('print_background', tpl.print_background if tpl else False))

        offset_x_mm = float(data.get('offset_x_mm', 0.0) or (tpl.default_offset_x_mm if tpl else 0.0) or 0.0)
        offset_y_mm = float(data.get('offset_y_mm', 0.0) or (tpl.default_offset_y_mm if tpl else 0.0) or 0.0)
        calling_system = str(data.get('called_by_system') or request.headers.get('X-Calling-System') or '').strip()
        data_source_used = str(data.get('data_source_used') or calling_system or '').strip()

        # สร้างไฟล์ PDF หรือ PNG
        if action_type in ('EXPORT_PNG', 'PREVIEW_PNG'):
            out_bytes = render_form_png_bytes(
                width_mm=width_mm,
                height_mm=height_mm,
                fields_schema=fields_schema,
                values=records[0],
                background_image=background_image or '',
                print_background=print_background,
                offset_x_mm=offset_x_mm,
                offset_y_mm=offset_y_mm,
                dpi=int(data.get('dpi', 300) or 300),
            )
            mime_type = 'image/png'
            ext = 'png'
        else:
            out_bytes = render_form_pdf_bytes(
                width_mm=width_mm,
                height_mm=height_mm,
                fields_schema=fields_schema,
                records=records,
                background_image=background_image or '',
                print_background=print_background,
                offset_x_mm=offset_x_mm,
                offset_y_mm=offset_y_mm,
            )
            mime_type = 'application/pdf'
            ext = 'pdf'

        # บันทึก Audit Log (ยกเว้น PREVIEW_PNG ที่เป็นเพียงการพรีวิวหน้าจอ)
        log_obj = None
        if action_type != 'PREVIEW_PNG':
            user = request.user
            first_rec = records[0] if records else {}
            summary_parts = []
            resolved_snapshot = {}
            for f in fields_schema:
                if f.get('field_type') == 'static_text':
                    continue
                k = f.get('key', '')
                lbl = f.get('label') or k
                disp = resolve_field_display_value(f, first_rec)
                if disp:
                    resolved_snapshot[lbl] = disp
                    if len(summary_parts) < 5:
                        summary_parts.append(f"{lbl}: {disp}")

            sys_tag = f"[{calling_system}] " if calling_system else ("[API Service] " if is_service_call else "")
            if len(records) > 1:
                summary_text = f"{sys_tag}[พิมพ์ชุด {len(records)} แผ่น] " + " | ".join(summary_parts)
            else:
                summary_text = f"{sys_tag}" + (" | ".join(summary_parts) if summary_parts else "พิมพ์แบบฟอร์มเปล่า")

            court_name = getattr(getattr(user, 'court', None), 'name', 'ศาลแขวงเชียงดาว')
            u_name = getattr(user, 'username', 'system')
            u_full = getattr(user, 'display_name', '') or (user.get_full_name() if hasattr(user, 'get_full_name') else '') or u_name

            log_obj = FormPrintLog.objects.create(
                user=user if getattr(user, 'is_authenticated', False) else None,
                username=u_name,
                user_full_name=u_full,
                department=getattr(user, 'department', '') or '',
                court_name=court_name,
                template=tpl,
                template_code=template_code,
                template_name=template_name,
                action_type=action_type,
                paper_size_label=paper_size_label,
                width_mm=width_mm,
                height_mm=height_mm,
                offset_x_mm=offset_x_mm,
                offset_y_mm=offset_y_mm,
                print_background=print_background,
                page_count=len(records),
                data_source_used=data_source_used,
                summary_text=summary_text[:1000],
                printed_data={
                    'fields_values': resolved_snapshot,
                    'raw_records': records[:50],
                    'field_positions_mm': [
                        {
                            'key': f.get('key'),
                            'label': f.get('label'),
                            'x_mm': round(float(f.get('x_mm', 0)) + offset_x_mm, 2),
                            'y_mm': round(float(f.get('y_mm', 0)) + offset_y_mm, 2),
                        }
                        for f in fields_schema
                    ],
                },
                ip_address=get_client_ip(request),
                user_agent=(request.META.get('HTTP_USER_AGENT') or '')[:255],
            )

        timestamp_str = timezone.localtime().strftime('%Y%m%d_%H%M%S')
        safe_code = "".join(ch if ch.isalnum() or ch in ('_', '-') else '_' for ch in template_code)
        filename = f"{safe_code}_{timestamp_str}.{ext}"

        if data.get('response_format') == 'binary' or request.query_params.get('format') == 'binary':
            resp = HttpResponse(out_bytes, content_type=mime_type)
            resp['Content-Disposition'] = f'attachment; filename="{filename}"'
            return resp

        b64_content = base64.b64encode(out_bytes).decode('utf-8')
        return Response({
            'success': True,
            'action_type': action_type,
            'mime_type': mime_type,
            'filename': filename,
            'page_count': len(records),
            'file_base64': b64_content,
            'log_id': log_obj.id if log_obj else None,
        })


# ==============================================================================
# 6. Print Audit Log Console ViewSet (For Admin Inspection)
# ==============================================================================
class FormPrintLogViewSet(viewsets.ReadOnlyModelViewSet):
    """
    GET /api/form/print-logs/
    สำหรับ Admin ตรวจสอบว่าใครพิมพ์อะไรไปเมื่อไหร่ พร้อมค้นหาและดูรายละเอียดข้อมูลทุกช่อง
    """
    serializer_class = FormPrintLogSerializer
    permission_classes = [permissions.IsAuthenticated]

    def get_queryset(self):
        is_admin = getattr(self.request, 'is_form_admin', False) or check_is_form_admin(self.request.user)
        qs = FormPrintLog.objects.all().order_by('-created_at')
        if not is_admin:
            qs = qs.filter(user=self.request.user)

        search = self.request.query_params.get('search', '').strip()
        action_type = self.request.query_params.get('action_type', '').strip()
        template_id = self.request.query_params.get('template_id', '').strip()
        username = self.request.query_params.get('username', '').strip()
        date_from = self.request.query_params.get('date_from', '').strip()
        date_to = self.request.query_params.get('date_to', '').strip()

        if search:
            qs = qs.filter(
                Q(user_full_name__icontains=search) |
                Q(username__icontains=search) |
                Q(template_name__icontains=search) |
                Q(summary_text__icontains=search) |
                Q(department__icontains=search)
            )
        if action_type and action_type != 'ALL':
            qs = qs.filter(action_type=action_type)
        if template_id and template_id.isdigit():
            qs = qs.filter(template_id=int(template_id))
        if username:
            qs = qs.filter(username__icontains=username)
        if date_from:
            qs = qs.filter(created_at__date__gte=date_from)
        if date_to:
            qs = qs.filter(created_at__date__lte=date_to)

        return qs[:300]

    @action(detail=False, methods=['get'])
    def summary(self, request):
        is_admin = getattr(request, 'is_form_admin', False) or check_is_form_admin(request.user)
        qs = FormPrintLog.objects.all()
        if not is_admin:
            qs = qs.filter(user=request.user)

        total_jobs = qs.count()
        total_pages = qs.aggregate(s=Sum('page_count'))['s'] or 0
        by_action = list(qs.values('action_type').annotate(count=Count('id')))
        by_template = list(qs.values('template_name').annotate(count=Count('id'), pages=Sum('page_count')).order_by('-count')[:10])

        return Response({
            'total_jobs': total_jobs,
            'total_pages': total_pages,
            'by_action': by_action,
            'by_template': by_template,
            'is_admin_view': is_admin,
        })
