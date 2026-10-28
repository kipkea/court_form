import csv
import io
from django.db.models import Q
from budget.models import User
from portal.models import Court
from formstudio.models import DataSourceConfig


DEFAULT_DATA_SOURCES = {
    'portal_users': {
        'name': 'ข้อมูลบุคลากรและผู้ใช้งานในระบบ (Portal Users)',
        'description': 'ดึงรายชื่อข้าราชการและบุคลากร คำนำหน้า ชื่อ-สกุล ตำแหน่ง กลุ่มงาน เบอร์โทร และสังกัดศาล จากระบบกลาง',
        'exposed_fields': [
            {'key': 'full_name', 'label': 'ชื่อ-นามสกุล (พร้อมคำนำหน้า)'},
            {'key': 'name_no_title', 'label': 'ชื่อ-นามสกุล (ไม่รวมคำนำหน้า)'},
            {'key': 'title', 'label': 'คำนำหน้า'},
            {'key': 'first_name', 'label': 'ชื่อตัว'},
            {'key': 'last_name', 'label': 'นามสกุล'},
            {'key': 'position', 'label': 'ตำแหน่ง'},
            {'key': 'department', 'label': 'กลุ่มงาน/ส่วนงาน'},
            {'key': 'phone_number', 'label': 'เบอร์โทรศัพท์'},
            {'key': 'email', 'label': 'อีเมล'},
            {'key': 'court_name', 'label': 'ชื่อศาล/หน่วยงาน'},
        ],
    },
    'courts': {
        'name': 'ข้อมูลศาลและที่อยู่หน่วยงานมาตรฐาน (Courts & Addresses)',
        'description': 'ดึงชื่อศาล รหัสหนังสือสารบรรณ ที่อยู่มาตรฐาน ตำบล อำเภอ จังหวัด และรหัสไปรษณีย์ สำหรับจ่าหน้าซองจดหมายราชการ',
        'exposed_fields': [
            {'key': 'court_name', 'label': 'ชื่อศาล/หน่วยงาน'},
            {'key': 'recipient_director', 'label': 'เรียน ผู้อำนวยการฯ (อัตโนมัติ)'},
            {'key': 'book_number', 'label': 'เลขที่หนังสือสารบรรณ'},
            {'key': 'full_address', 'label': 'ที่อยู่เต็ม (บรรทัดเดียว)'},
            {'key': 'address_line1', 'label': 'ที่อยู่บรรทัดที่ 1 (เลขที่/อาคาร/ถนน/ตำบล)'},
            {'key': 'address_line2', 'label': 'ที่อยู่บรรทัดที่ 2 (อำเภอ/จังหวัด)'},
            {'key': 'subdistrict', 'label': 'ตำบล/แขวง'},
            {'key': 'district', 'label': 'อำเภอ/เขต'},
            {'key': 'province', 'label': 'จังหวัด'},
            {'key': 'postal_code', 'label': 'รหัสไปรษณีย์ (5 หลัก)'},
            {'key': 'phone', 'label': 'เบอร์โทรศัพท์หน่วยงาน'},
            {'key': 'fax', 'label': 'เบอร์โทรสาร (Fax)'},
        ],
    },
}


def fetch_datasource_records(source_code: str, request_user, search: str = "") -> dict:
    """
    ดึงข้อมูลจากแหล่งข้อมูลในระบบที่ผ่านการกรองและอนุญาตโดย Admin แล้ว
    """
    cfg = DataSourceConfig.objects.filter(source_code=source_code).first()
    if cfg and not cfg.is_enabled:
        return {
            'enabled': False,
            'source_code': source_code,
            'error': 'แหล่งข้อมูลนี้ถูกปิดการอนุญาตโดยผู้ดูแลระบบ (Admin)',
            'records': [],
            'fields': [],
        }

    meta = DEFAULT_DATA_SOURCES.get(source_code, {})
    allowed_field_keys = None
    if cfg and cfg.exposed_fields:
        allowed_field_keys = set(cfg.exposed_fields)

    all_fields = meta.get('exposed_fields', [])
    if allowed_field_keys:
        exposed_fields = [f for f in all_fields if f['key'] in allowed_field_keys]
        if not exposed_fields:
            exposed_fields = all_fields
    else:
        exposed_fields = all_fields

    records = []

    if source_code == 'portal_users':
        qs = User.objects.select_related('court').all()
        if not cfg or cfg.active_only:
            qs = qs.filter(is_active=True)
        if cfg and cfg.same_court_only and getattr(request_user, 'court_id', None):
            qs = qs.filter(court_id=request_user.court_id)
        if cfg and isinstance(cfg.filter_config, dict):
            dept_filter = (cfg.filter_config.get('department') or '').strip()
            if dept_filter:
                qs = qs.filter(department__icontains=dept_filter)
        if search:
            qs = qs.filter(
                Q(first_name__icontains=search) |
                Q(last_name__icontains=search) |
                Q(username__icontains=search) |
                Q(position__icontains=search) |
                Q(department__icontains=search)
            )
        qs = qs.order_by('seniority', 'first_name', 'id')[:300]

        for u in qs:
            name_no_title = f"{u.first_name} {u.last_name}".strip() or u.username
            full_name = f"{u.title}{name_no_title}".strip() if u.title else name_no_title
            court_name = u.court.name if getattr(u, 'court', None) else 'ศาลแขวงเชียงดาว'
            row = {
                'id': u.id,
                '_display_title': full_name,
                '_display_subtitle': f"{u.position or 'เจ้าหน้าที่'} | {u.department or '-'}",
                'full_name': full_name,
                'name_no_title': name_no_title,
                'title': u.title or '',
                'first_name': u.first_name or '',
                'last_name': u.last_name or '',
                'position': u.position or '',
                'department': u.department or '',
                'phone_number': u.phone_number or '',
                'email': u.email or '',
                'court_name': court_name,
            }
            if allowed_field_keys:
                row = {
                    k: v for k, v in row.items()
                    if k in ('id', '_display_title', '_display_subtitle') or k in allowed_field_keys
                }
            records.append(row)

    elif source_code == 'courts':
        qs = Court.objects.select_related('address').all()
        if not cfg or cfg.active_only:
            qs = qs.filter(is_active=True)
        if search:
            qs = qs.filter(
                Q(name__icontains=search) |
                Q(code__icontains=search) |
                Q(book_number__icontains=search) |
                Q(address__province__icontains=search) |
                Q(address__district__icontains=search)
            )
        qs = qs.order_by('id')[:300]

        for c in qs:
            addr = c.address
            line1_parts = []
            line2_parts = []
            postal_code = ''
            subdistrict = ''
            district = ''
            province = ''
            if addr:
                postal_code = addr.postal_code or ''
                subdistrict = addr.subdistrict or ''
                district = addr.district or ''
                province = addr.province or ''
                is_bkk = 'กรุงเทพ' in province
                if addr.house_number:
                    line1_parts.append(f"เลขที่ {addr.house_number}")
                if addr.building:
                    line1_parts.append(addr.building)
                if addr.village_no:
                    line1_parts.append(f"หมู่ที่ {addr.village_no}")
                if addr.soi:
                    line1_parts.append(f"ซอย{addr.soi}")
                if addr.road:
                    line1_parts.append(f"ถนน{addr.road}")
                if subdistrict:
                    line1_parts.append(f"แขวง{subdistrict}" if is_bkk else f"ตำบล{subdistrict}")
                if district:
                    line2_parts.append(f"เขต{district}" if is_bkk else f"อำเภอ{district}")
                if province:
                    line2_parts.append("กรุงเทพมหานคร" if is_bkk else f"จังหวัด{province}")

            full_addr = c.full_address or " ".join(line1_parts + line2_parts + ([postal_code] if postal_code else []))
            row = {
                'id': c.id,
                '_display_title': f"{c.name} ({c.code})",
                '_display_subtitle': full_addr or f"รหัสหนังสือ: {c.book_number or '-'}",
                'court_name': c.name,
                'recipient_director': f"ผู้อำนวยการสำนักอำนวยการประจำ{c.name}" if 'แขวง' in c.name or 'จังหวัด' in c.name else f"ผู้อำนวยการประจำ{c.name}",
                'book_number': c.book_number or '',
                'full_address': full_addr,
                'address_line1': " ".join(line1_parts).strip(),
                'address_line2': " ".join(line2_parts).strip(),
                'subdistrict': subdistrict,
                'district': district,
                'province': province,
                'postal_code': postal_code,
                'phone': c.phone or '',
                'fax': c.fax or '',
            }
            if allowed_field_keys:
                row = {
                    k: v for k, v in row.items()
                    if k in ('id', '_display_title', '_display_subtitle') or k in allowed_field_keys
                }
            records.append(row)

    return {
        'enabled': True,
        'source_code': source_code,
        'name': cfg.name if cfg else meta.get('name', source_code),
        'description': cfg.description if cfg else meta.get('description', ''),
        'fields': exposed_fields,
        'records': records,
    }


def parse_tabular_file(file_obj) -> dict:
    """
    อ่านไฟล์ CSV หรือ Excel (.xlsx) เพื่อนำมาใช้พิมพ์ต่อเนื่องหลายแผ่น (Batch / Mail Merge)
    คืนค่า {'columns': [...], 'rows': [{...}, ...]}
    """
    filename = (getattr(file_obj, 'name', '') or '').lower()
    raw_bytes = file_obj.read()

    if filename.endswith('.xlsx'):
        import openpyxl
        wb = openpyxl.load_workbook(io.BytesIO(raw_bytes), data_only=True)
        ws = wb.active
        all_rows = list(ws.iter_rows(values_only=True))
        if not all_rows:
            return {'columns': [], 'rows': []}
        headers = [str(h).strip() if h is not None else f"Col_{i+1}" for i, h in enumerate(all_rows[0])]
        rows = []
        for r in all_rows[1:]:
            if not any(cell is not None and str(cell).strip() != '' for cell in r):
                continue
            item = {}
            for idx, col_name in enumerate(headers):
                val = r[idx] if idx < len(r) else ''
                item[col_name] = '' if val is None else str(val).strip()
            rows.append(item)
        return {'columns': headers, 'rows': rows}

    # Default: CSV (รองรับ UTF-8-SIG และ TIS-620/CP874 สำหรับไฟล์ Excel ภาษาไทย)
    text = None
    for enc in ('utf-8-sig', 'utf-8', 'cp874', 'tis-620'):
        try:
            text = raw_bytes.decode(enc)
            break
        except UnicodeDecodeError:
            continue
    if text is None:
        text = raw_bytes.decode('utf-8', errors='replace')

    reader = csv.reader(io.StringIO(text))
    all_rows = list(reader)
    if not all_rows:
        return {'columns': [], 'rows': []}

    headers = [str(h).strip() or f"Col_{i+1}" for i, h in enumerate(all_rows[0])]
    rows = []
    for r in all_rows[1:]:
        if not any(str(cell).strip() for cell in r):
            continue
        item = {}
        for idx, col_name in enumerate(headers):
            item[col_name] = str(r[idx]).strip() if idx < len(r) else ''
        rows.append(item)
    return {'columns': headers, 'rows': rows}
