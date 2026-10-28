import io
import base64
import os
import sys
from pathlib import Path

current_dir = Path(__file__).resolve().parent
sys.path.insert(0, str(current_dir))
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'config.settings')

import django
django.setup()

from PIL import Image, ImageDraw
from budget.models import User
from portal.models import PortalApp, UserAppPermission
from formstudio.models import (
    PaperSizePreset,
    DataSourceConfig,
    FormTemplate,
    PrinterOffsetProfile,
)
from formstudio.services.datasource_service import DEFAULT_DATA_SOURCES


def make_cheque_guide_base64() -> str:
    """
    สร้างภาพพื้นหลังจำลองใบเช็คธนาคาร (178 x 89 mm -> 1068 x 534 px)
    สำหรับทาบตำแหน่งบนหน้าจอ (print_background=False)
    """
    w, h = 1068, 534
    img = Image.new('RGB', (w, h), '#F4F9F5')
    draw = ImageDraw.Draw(img)

    # กรอบนอกและลวดลายน้ำจำลอง
    draw.rectangle([8, 8, w - 8, h - 8], outline='#90CAF9', width=2)
    draw.rectangle([16, 16, w - 16, h - 16], outline='#C8E6C9', width=1)

    # ช่องวันที่ 8 ช่อง มุมขวาบน (x=114..160.4 mm, y=12..20 mm) -> 1 mm = 6 px
    for i in range(8):
        bx = int((114.0 + i * 5.8) * 6)
        by = int(11.0 * 6)
        bw = int(5.4 * 6)
        bh = int(8.5 * 6)
        draw.rectangle([bx, by, bx + bw, by + bh], outline='#64B5F6', fill='#FFFFFF', width=2)

    # เส้นบรรทัด "จ่าย Pay" (x=24..145 mm, y=35 mm)
    draw.line([(int(24 * 6), int(35 * 6)), (int(146 * 6), int(35 * 6))], fill='#78909C', width=2)
    # กล่องคำว่า "หรือผู้ถือ" (x=148..170 mm, y=28..35 mm)
    draw.rectangle([int(148 * 6), int(27 * 6), int(171 * 6), int(35 * 6)], outline='#B0BEC5', width=1)

    # เส้นบรรทัด "จำนวนเงินตัวอักษร Baht" (x=28..168 mm, y=47 mm)
    draw.line([(int(28 * 6), int(47 * 6)), (int(168 * 6), int(47 * 6))], fill='#78909C', width=2)

    # กล่องจำนวนเงินตัวเลข ฿ (x=108..168 mm, y=53..64 mm)
    draw.rectangle([int(108 * 6), int(53 * 6), int(168 * 6), int(64 * 6)], outline='#1E88E5', fill='#FFFFFF', width=2)

    # เส้นลงลายมือชื่อผู้สั่งจ่าย (x=110..168 mm, y=79 mm)
    draw.line([(int(110 * 6), int(79 * 6)), (int(168 * 6), int(79 * 6))], fill='#78909C', width=2)

    # แถบ MICR ด้านล่างเช็ค
    draw.rectangle([16, int(81 * 6), w - 16, h - 16], fill='#FFFFFF', outline='#E0E0E0')

    buf = io.BytesIO()
    img.save(buf, format='PNG')
    return 'data:image/png;base64,' + base64.b64encode(buf.getvalue()).decode('utf-8')


def make_envelope_dl_guide_base64() -> str:
    """
    สร้างภาพพื้นหลังจำลองซองจดหมายราชการ DL (220 x 110 mm -> 1320 x 660 px)
    มีช่องรหัสไปรษณีย์ 5 ช่องมุมขวาล่าง
    """
    w, h = 1320, 660
    img = Image.new('RGB', (w, h), '#FFFDF9')
    draw = ImageDraw.Draw(img)

    draw.rectangle([6, 6, w - 6, h - 6], outline='#D7CCC8', width=2)
    # กรอบติดดวงตราไปรษณียากร มุมขวาบน
    draw.rectangle([int(190 * 6), int(10 * 6), int(210 * 6), int(34 * 6)], outline='#BCAAA4', width=2)

    # ช่องรหัสไปรษณีย์ 5 ช่อง (x=140..172.5 mm, y=88..97 mm)
    for i in range(5):
        bx = int((140.0 + i * 6.5) * 6)
        by = int(87.0 * 6)
        bw = int(5.8 * 6)
        bh = int(9.0 * 6)
        draw.rectangle([bx, by, bx + bw, by + bh], outline='#E53935', fill='#FFFFFF', width=2)

    buf = io.BytesIO()
    img.save(buf, format='PNG')
    return 'data:image/png;base64,' + base64.b64encode(buf.getvalue()).decode('utf-8')


def seed_all():
    print("1. Seeding PaperSizePreset...")
    presets = [
        ('A4', 'กระดาษ A4 มาตรฐาน (210 × 297 มม.)', 'STANDARD', 210.0, 297.0, 'portrait', 'กระดาษเอกสารราชการและแบบสอบถามมาตรฐาน', 1),
        ('A5', 'กระดาษ A5 ครึ่งแผ่น (148 × 210 มม.)', 'STANDARD', 148.0, 210.0, 'portrait', 'กระดาษบันทึกข้อความย่อ / ใบสำคัญขนาดครึ่ง A4', 2),
        ('ENV_DL', 'ซองจดหมายมาตรฐาน DL (220 × 110 มม.)', 'ENVELOPE', 220.0, 110.0, 'landscape', 'ซองจดหมายราชการพับ 3 ส่วน มาตรฐานไปรษณีย์', 3),
        ('ENV_GOV9X4', 'ซองจดหมายราชการ 9×4 นิ้ว (228.6 × 101.6 มม.)', 'ENVELOPE', 228.6, 101.6, 'landscape', 'ซองจดหมายราชการขนาดยาว 9 × 4 นิ้ว', 4),
        ('ENV_C5', 'ซองเอกสารขนาดกลาง C5 (229 × 162 มม.)', 'ENVELOPE', 229.0, 162.0, 'landscape', 'ซองสำหรับใส่กระดาษ A4 พับครึ่ง', 5),
        ('ENV_C4', 'ซองเอกสารขนาดใหญ่ C4 (324 × 229 มม.)', 'ENVELOPE', 324.0, 229.0, 'landscape', 'ซองน้ำตาลขยายสำหรับใส่กระดาษ A4 โดยไม่ต้องพับ', 6),
        ('CHEQUE_STD', 'สมุดเช็คธนาคารมาตรฐาน (178 × 89 มม.)', 'CHEQUE', 178.0, 89.0, 'landscape', 'ขนาดใบเช็คธนาคารพาณิชย์และธนาคารกรุงไทยมาตรฐาน (7 × 3.5 นิ้ว)', 7),
        ('CHEQUE_STUB', 'สมุดเช็คพร้อมต้นขั้ว (228 × 89 มม.)', 'CHEQUE', 228.0, 89.0, 'landscape', 'ขนาดใบเช็ครวมส่วนต้นขั้วด้านซ้าย (9 × 3.5 นิ้ว)', 8),
    ]
    for code, name, cat, w, h, orient, desc, order in presets:
        PaperSizePreset.objects.update_or_create(
            code=code,
            defaults={
                'name': name,
                'category': cat,
                'width_mm': w,
                'height_mm': h,
                'default_orientation': orient,
                'description': desc,
                'sort_order': order,
                'is_active': True,
            }
        )

    print("2. Seeding DataSourceConfig...")
    for code, meta in DEFAULT_DATA_SOURCES.items():
        DataSourceConfig.objects.update_or_create(
            source_code=code,
            defaults={
                'name': meta['name'],
                'description': meta['description'],
                'is_enabled': True,
                'same_court_only': False,
                'active_only': True,
                'exposed_fields': [f['key'] for f in meta['exposed_fields']],
            }
        )

    print("3. Seeding PrinterOffsetProfile...")
    PrinterOffsetProfile.objects.update_or_create(
        name='เครื่องพิมพ์เลเซอร์มาตรฐาน (ค่าเริ่มต้น 0.0 มม.)',
        is_shared=True,
        defaults={'offset_x_mm': 0.0, 'offset_y_mm': 0.0}
    )
    PrinterOffsetProfile.objects.update_or_create(
        name='ถาดป้อนซองจดหมาย (ชดเชย X:+1.5, Y:+1.0 มม.)',
        is_shared=True,
        defaults={'offset_x_mm': 1.5, 'offset_y_mm': 1.0}
    )
    PrinterOffsetProfile.objects.update_or_create(
        name='เครื่องพิมพ์เช็ค / แคร่ป้อนมือ (ชดเชย X:-1.0, Y:+0.5 มม.)',
        is_shared=True,
        defaults={'offset_x_mm': -1.0, 'offset_y_mm': 0.5}
    )

    print("4. Seeding Routine FormTemplates...")
    cheque_bg = make_cheque_guide_base64()
    env_dl_bg = make_envelope_dl_guide_base64()

    # แม่แบบที่ 1: พิมพ์เช็คธนาคารมาตรฐาน (178 x 89 mm)
    FormTemplate.objects.update_or_create(
        code='cheque_standard',
        defaults={
            'name': 'งานพิมพ์เช็คธนาคาร (มาตรฐานเช็คสั่งจ่าย 178×89 มม.)',
            'category': 'CHEQUE',
            'description': 'พิมพ์ลงใบเช็คธนาคารจริง (ไม่พิมพ์ภาพพื้นหลัง) มีตัวช่วยแปลงจำนวนเงินเป็นตัวอักษรภาษาไทยอัตโนมัติ ขีดคร่อม A/C PAYEE ONLY และช่องวันที่ 8 หลัก',
            'paper_preset': 'CHEQUE_STD',
            'width_mm': 178.0,
            'height_mm': 89.0,
            'orientation': 'landscape',
            'background_image': cheque_bg,
            'print_background': False,
            'grid_size_mm': 2.0,
            'allowed_data_source': 'portal_users',
            'sort_order': 1,
            'is_active': True,
            'fields_schema': [
                {
                    'id': 'f_ac_payee',
                    'key': 'ac_payee',
                    'label': 'ขีดคร่อม A/C PAYEE ONLY',
                    'field_type': 'cheque_cross',
                    'x_mm': 10.0,
                    'y_mm': 22.0,
                    'width_mm': 38.0,
                    'height_mm': 14.0,
                    'font_size': 13.0,
                    'font_bold': True,
                    'align': 'center',
                    'color': '#B71C1C',
                    'cross_text': 'A/C PAYEE ONLY',
                    'default_value': 'true',
                    'printable': True,
                },
                {
                    'id': 'f_cheque_date',
                    'key': 'cheque_date',
                    'label': 'วันที่สั่งจ่าย (8 หลัก ววดดปปปป)',
                    'field_type': 'box_group',
                    'x_mm': 114.0,
                    'y_mm': 11.5,
                    'width_mm': 46.4,
                    'height_mm': 8.5,
                    'font_size': 17.0,
                    'font_bold': True,
                    'align': 'center',
                    'letter_spacing_mm': 5.8,
                    'max_boxes': 8,
                    'default_value': '28102569',
                    'printable': True,
                },
                {
                    'id': 'f_payee_name',
                    'key': 'payee_name',
                    'label': 'สั่งจ่าย (ชื่อผู้รับเงิน / หน่วยงาน)',
                    'field_type': 'text',
                    'x_mm': 28.0,
                    'y_mm': 27.5,
                    'width_mm': 115.0,
                    'height_mm': 8.0,
                    'font_size': 17.0,
                    'font_bold': True,
                    'align': 'left',
                    'default_value': 'นางสาวสมหญิง รักความยุติธรรม',
                    'data_binding_key': 'full_name',
                    'printable': True,
                },
                {
                    'id': 'f_strike_bearer',
                    'key': 'strike_bearer',
                    'label': 'ขีดฆ่า "หรือผู้ถือ"',
                    'field_type': 'strike_line',
                    'x_mm': 148.0,
                    'y_mm': 28.0,
                    'width_mm': 22.0,
                    'height_mm': 6.0,
                    'font_size': 14.0,
                    'font_bold': True,
                    'align': 'center',
                    'default_value': 'true',
                    'printable': True,
                },
                {
                    'id': 'f_amount_num',
                    'key': 'amount_num',
                    'label': 'จำนวนเงินตัวเลข (บาท)',
                    'field_type': 'currency',
                    'x_mm': 112.0,
                    'y_mm': 54.0,
                    'width_mm': 52.0,
                    'height_mm': 9.0,
                    'font_size': 18.0,
                    'font_bold': True,
                    'align': 'right',
                    'prefix': '**',
                    'suffix': '**',
                    'default_value': '15420.00',
                    'printable': True,
                },
                {
                    'id': 'f_amount_text',
                    'key': 'amount_text',
                    'label': 'จำนวนเงินตัวอักษร (แปลงอัตโนมัติ)',
                    'field_type': 'bahttext',
                    'source_field': 'amount_num',
                    'wrap_brackets': True,
                    'x_mm': 32.0,
                    'y_mm': 39.5,
                    'width_mm': 132.0,
                    'height_mm': 8.0,
                    'font_size': 16.5,
                    'font_bold': True,
                    'align': 'left',
                    'default_value': '',
                    'printable': True,
                },
            ],
        }
    )

    # แม่แบบที่ 2: พิมพ์เช็คพร้อมต้นขั้ว (228 x 89 mm)
    FormTemplate.objects.update_or_create(
        code='cheque_with_stub',
        defaults={
            'name': 'งานพิมพ์เช็คพร้อมต้นขั้ว (228×89 มม.)',
            'category': 'CHEQUE',
            'description': 'สำหรับสมุดเช็คที่มีต้นขั้วด้านซ้าย (50 มม.) พิมพ์รายละเอียดลงทั้งต้นขั้วและตัวเช็คพร้อมกันในครั้งเดียว',
            'paper_preset': 'CHEQUE_STUB',
            'width_mm': 228.0,
            'height_mm': 89.0,
            'orientation': 'landscape',
            'background_image': '',
            'print_background': False,
            'grid_size_mm': 2.0,
            'allowed_data_source': 'portal_users',
            'sort_order': 2,
            'is_active': True,
            'fields_schema': [
                {
                    'id': 's_stub_date',
                    'key': 'stub_date',
                    'label': '[ต้นขั้ว] วันที่',
                    'field_type': 'date_thai',
                    'date_format': 'short',
                    'x_mm': 6.0,
                    'y_mm': 12.0,
                    'width_mm': 40.0,
                    'height_mm': 7.0,
                    'font_size': 14.0,
                    'font_bold': False,
                    'align': 'left',
                    'default_value': '2026-10-28',
                    'printable': True,
                },
                {
                    'id': 's_stub_payee',
                    'key': 'payee_name',
                    'label': 'ชื่อผู้รับเงิน (พิมพ์ทั้งต้นขั้วและตัวเช็ค)',
                    'field_type': 'text',
                    'x_mm': 6.0,
                    'y_mm': 24.0,
                    'width_mm': 42.0,
                    'height_mm': 8.0,
                    'font_size': 14.0,
                    'font_bold': True,
                    'align': 'left',
                    'default_value': 'นายสมชาย ใจดี',
                    'data_binding_key': 'full_name',
                    'printable': True,
                },
                {
                    'id': 's_stub_memo',
                    'key': 'stub_memo',
                    'label': '[ต้นขั้ว] รายการ/อ้างอิงฎีกา',
                    'field_type': 'multiline',
                    'x_mm': 6.0,
                    'y_mm': 36.0,
                    'width_mm': 42.0,
                    'height_mm': 16.0,
                    'font_size': 13.0,
                    'font_bold': False,
                    'align': 'left',
                    'default_value': 'ค่าตอบแทนการปฏิบัติงานนอกเวลาราชการ',
                    'printable': True,
                },
                {
                    'id': 's_stub_amount',
                    'key': 'amount_num',
                    'label': 'จำนวนเงิน (บาท)',
                    'field_type': 'currency',
                    'x_mm': 6.0,
                    'y_mm': 58.0,
                    'width_mm': 40.0,
                    'height_mm': 8.0,
                    'font_size': 15.0,
                    'font_bold': True,
                    'align': 'right',
                    'default_value': '8500.00',
                    'printable': True,
                },
                {
                    'id': 's_cheque_date',
                    'key': 'cheque_date',
                    'label': '[ตัวเช็ค] วันที่ 8 หลัก',
                    'field_type': 'box_group',
                    'x_mm': 164.0,
                    'y_mm': 11.5,
                    'width_mm': 46.4,
                    'height_mm': 8.5,
                    'font_size': 17.0,
                    'font_bold': True,
                    'align': 'center',
                    'letter_spacing_mm': 5.8,
                    'max_boxes': 8,
                    'default_value': '28102569',
                    'printable': True,
                },
                {
                    'id': 's_cheque_payee',
                    'key': 'cheque_payee_copy',
                    'label': '[ตัวเช็ค] สั่งจ่ายชื่อผู้รับเงิน',
                    'field_type': 'text',
                    'x_mm': 78.0,
                    'y_mm': 27.5,
                    'width_mm': 115.0,
                    'height_mm': 8.0,
                    'font_size': 17.0,
                    'font_bold': True,
                    'align': 'left',
                    'default_value': 'นายสมชาย ใจดี',
                    'data_binding_key': 'full_name',
                    'printable': True,
                },
                {
                    'id': 's_cheque_bahttext',
                    'key': 'amount_text',
                    'label': '[ตัวเช็ค] จำนวนเงินตัวอักษร',
                    'field_type': 'bahttext',
                    'source_field': 'amount_num',
                    'wrap_brackets': True,
                    'x_mm': 82.0,
                    'y_mm': 39.5,
                    'width_mm': 132.0,
                    'height_mm': 8.0,
                    'font_size': 16.5,
                    'font_bold': True,
                    'align': 'left',
                    'default_value': '',
                    'printable': True,
                },
                {
                    'id': 's_cheque_amount_box',
                    'key': 'cheque_amount_box',
                    'label': '[ตัวเช็ค] จำนวนเงินตัวเลขในกรอบ',
                    'field_type': 'currency',
                    'x_mm': 162.0,
                    'y_mm': 54.0,
                    'width_mm': 52.0,
                    'height_mm': 9.0,
                    'font_size': 18.0,
                    'font_bold': True,
                    'align': 'right',
                    'prefix': '**',
                    'suffix': '**',
                    'default_value': '8500.00',
                    'printable': True,
                },
            ],
        }
    )

    # แม่แบบที่ 3: จ่าหน้าซองจดหมายราชการ DL (220 x 110 mm)
    FormTemplate.objects.update_or_create(
        code='envelope_dl_official',
        defaults={
            'name': 'งานจ่าหน้าซองจดหมายราชการ (ซอง DL มาตรฐาน 220×110 มม.)',
            'category': 'ENVELOPE',
            'description': 'สำหรับจ่าหน้าซองจดหมายราชการถึงหน่วยงานศาลหรือบุคคล พร้อมลงช่องรหัสไปรษณีย์ 5 หลักอัตโนมัติ และดึงรายชื่อศาลจากระบบได้ทันที',
            'paper_preset': 'ENV_DL',
            'width_mm': 220.0,
            'height_mm': 110.0,
            'orientation': 'landscape',
            'background_image': env_dl_bg,
            'print_background': False,
            'grid_size_mm': 5.0,
            'allowed_data_source': 'courts',
            'sort_order': 3,
            'is_active': True,
            'fields_schema': [
                {
                    'id': 'e_sender_org',
                    'key': 'sender_org',
                    'label': 'ชื่อหน่วยงานผู้ส่ง (มุมซ้ายบน)',
                    'field_type': 'text',
                    'x_mm': 14.0,
                    'y_mm': 12.0,
                    'width_mm': 90.0,
                    'height_mm': 7.0,
                    'font_size': 15.0,
                    'font_bold': True,
                    'align': 'left',
                    'default_value': 'ศาลแขวงเชียงดาว จังหวัดเชียงใหม่',
                    'printable': True,
                },
                {
                    'id': 'e_doc_no',
                    'key': 'doc_no',
                    'label': 'ที่หนังสือส่ง (ศย ...)',
                    'field_type': 'text',
                    'x_mm': 14.0,
                    'y_mm': 20.0,
                    'width_mm': 85.0,
                    'height_mm': 7.0,
                    'font_size': 14.0,
                    'font_bold': False,
                    'align': 'left',
                    'default_value': 'ที่ ศย 305.028/',
                    'printable': True,
                },
                {
                    'id': 'e_prefix',
                    'key': 'recipient_prefix',
                    'label': 'คำขึ้นต้นผู้รับ (เช่น เรียน)',
                    'field_type': 'text',
                    'x_mm': 62.0,
                    'y_mm': 42.0,
                    'width_mm': 25.0,
                    'height_mm': 8.0,
                    'font_size': 18.0,
                    'font_bold': True,
                    'align': 'left',
                    'default_value': 'เรียน',
                    'printable': True,
                },
                {
                    'id': 'e_recipient_name',
                    'key': 'recipient_name',
                    'label': 'ชื่อผู้รับ / ตำแหน่ง / หน่วยงานปลายทาง',
                    'field_type': 'text',
                    'x_mm': 78.0,
                    'y_mm': 42.0,
                    'width_mm': 125.0,
                    'height_mm': 8.0,
                    'font_size': 18.0,
                    'font_bold': True,
                    'align': 'left',
                    'default_value': 'ผู้อำนวยการสำนักอำนวยการประจำศาลจังหวัดเชียงใหม่',
                    'data_binding_key': 'recipient_director',
                    'printable': True,
                },
                {
                    'id': 'e_addr_line1',
                    'key': 'address_line1',
                    'label': 'ที่อยู่บรรทัดที่ 1 (เลขที่/ถนน/ตำบล)',
                    'field_type': 'text',
                    'x_mm': 78.0,
                    'y_mm': 53.0,
                    'width_mm': 128.0,
                    'height_mm': 8.0,
                    'font_size': 16.5,
                    'font_bold': False,
                    'align': 'left',
                    'default_value': 'ถนนโชตนา ตำบลช้างเผือก',
                    'data_binding_key': 'address_line1',
                    'printable': True,
                },
                {
                    'id': 'e_addr_line2',
                    'key': 'address_line2',
                    'label': 'ที่อยู่บรรทัดที่ 2 (อำเภอ/จังหวัด)',
                    'field_type': 'text',
                    'x_mm': 78.0,
                    'y_mm': 64.0,
                    'width_mm': 128.0,
                    'height_mm': 8.0,
                    'font_size': 16.5,
                    'font_bold': False,
                    'align': 'left',
                    'default_value': 'อำเภอเมืองเชียงใหม่ จังหวัดเชียงใหม่',
                    'data_binding_key': 'address_line2',
                    'printable': True,
                },
                {
                    'id': 'e_postal_code',
                    'key': 'postal_code',
                    'label': 'รหัสไปรษณีย์ (5 หลักแยกช่อง)',
                    'field_type': 'box_group',
                    'x_mm': 140.0,
                    'y_mm': 87.5,
                    'width_mm': 32.5,
                    'height_mm': 9.0,
                    'font_size': 18.0,
                    'font_bold': True,
                    'align': 'center',
                    'letter_spacing_mm': 6.5,
                    'max_boxes': 5,
                    'default_value': '50300',
                    'data_binding_key': 'postal_code',
                    'printable': True,
                },
            ],
        }
    )

    # แม่แบบที่ 4: จ่าหน้าซองเอกสารขนาดกลาง C5 (229 x 162 mm)
    FormTemplate.objects.update_or_create(
        code='envelope_c5_document',
        defaults={
            'name': 'งานจ่าหน้าซองเอกสารขนาดกลาง (ซอง C5 229×162 มม.)',
            'category': 'ENVELOPE',
            'description': 'สำหรับส่งเอกสารราชการหรือสำนวนคดีขนาดซอง C5 ดึงข้อมูลศาลหรือบุคลากรมาพิมพ์ได้ทันที',
            'paper_preset': 'ENV_C5',
            'width_mm': 229.0,
            'height_mm': 162.0,
            'orientation': 'landscape',
            'background_image': '',
            'print_background': False,
            'grid_size_mm': 5.0,
            'allowed_data_source': 'courts',
            'sort_order': 4,
            'is_active': True,
            'fields_schema': [
                {
                    'id': 'c5_sender',
                    'key': 'sender_org',
                    'label': 'หน่วยงานผู้ส่ง',
                    'field_type': 'multiline',
                    'x_mm': 16.0,
                    'y_mm': 14.0,
                    'width_mm': 95.0,
                    'height_mm': 18.0,
                    'font_size': 15.0,
                    'font_bold': True,
                    'align': 'left',
                    'default_value': 'ศาลแขวงเชียงดาว\nอำเภอเชียงดาว จังหวัดเชียงใหม่ 50170',
                    'printable': True,
                },
                {
                    'id': 'c5_service_type',
                    'key': 'service_type',
                    'label': 'ประเภทการส่ง (เช่น ด่วนที่สุด / ลงทะเบียน)',
                    'field_type': 'text',
                    'x_mm': 16.0,
                    'y_mm': 38.0,
                    'width_mm': 65.0,
                    'height_mm': 9.0,
                    'font_size': 18.0,
                    'font_bold': True,
                    'align': 'center',
                    'color': '#C62828',
                    'draw_border': True,
                    'default_value': 'ด่วนที่สุด / ลงทะเบียน',
                    'printable': True,
                },
                {
                    'id': 'c5_recipient',
                    'key': 'recipient_name',
                    'label': 'ชื่อผู้รับ / หน่วยงาน',
                    'field_type': 'text',
                    'x_mm': 70.0,
                    'y_mm': 68.0,
                    'width_mm': 140.0,
                    'height_mm': 10.0,
                    'font_size': 20.0,
                    'font_bold': True,
                    'align': 'left',
                    'default_value': 'เรียน ผู้อำนวยการสำนักอำนวยการประจำศาลแขวงเชียงดาว',
                    'data_binding_key': 'recipient_director',
                    'printable': True,
                },
                {
                    'id': 'c5_full_addr',
                    'key': 'full_address',
                    'label': 'ที่อยู่ผู้รับ',
                    'field_type': 'multiline',
                    'x_mm': 70.0,
                    'y_mm': 82.0,
                    'width_mm': 140.0,
                    'height_mm': 25.0,
                    'font_size': 18.0,
                    'font_bold': False,
                    'align': 'left',
                    'default_value': 'เลขที่ 399 หมู่ที่ 6 ตำบลเชียงดาว อำเภอเชียงดาว จังหวัดเชียงใหม่',
                    'data_binding_key': 'full_address',
                    'printable': True,
                },
                {
                    'id': 'c5_postal',
                    'key': 'postal_code',
                    'label': 'รหัสไปรษณีย์',
                    'field_type': 'text',
                    'x_mm': 130.0,
                    'y_mm': 125.0,
                    'width_mm': 60.0,
                    'height_mm': 10.0,
                    'font_size': 22.0,
                    'font_bold': True,
                    'align': 'left',
                    'default_value': '50170',
                    'data_binding_key': 'postal_code',
                    'printable': True,
                },
            ],
        }
    )

    # แม่แบบที่ 5: แบบสอบถามประเมินความพึงพอใจ (A4 210 x 297 mm)
    FormTemplate.objects.update_or_create(
        code='survey_satisfaction_a4',
        defaults={
            'name': 'แบบสอบถามประเมินความพึงพอใจผู้มาติดต่อราชการศาล (A4)',
            'category': 'SURVEY',
            'description': 'แบบฟอร์มขนาด A4 มาตรฐาน พร้อมหัวแบบสอบถาม ช่องกรอกข้อมูลผู้ติดต่อ ช่องติ๊กเครื่องหมาย ✓ และข้อเสนอแนะ',
            'paper_preset': 'A4',
            'width_mm': 210.0,
            'height_mm': 297.0,
            'orientation': 'portrait',
            'background_image': '',
            'print_background': True,
            'grid_size_mm': 5.0,
            'allowed_data_source': 'portal_users',
            'sort_order': 5,
            'is_active': True,
            'fields_schema': [
                {
                    'id': 'sv_header',
                    'key': 'static_header',
                    'label': '[หัวกระดาษ] ชื่อแบบสอบถาม',
                    'field_type': 'static_text',
                    'x_mm': 20.0,
                    'y_mm': 20.0,
                    'width_mm': 170.0,
                    'height_mm': 10.0,
                    'font_size': 20.0,
                    'font_bold': True,
                    'align': 'center',
                    'default_value': 'แบบสอบถามความพึงพอใจของผู้มาติดต่อราชการ ศาลแขวงเชียงดาว',
                    'printable': True,
                },
                {
                    'id': 'sv_date',
                    'key': 'survey_date',
                    'label': 'วันที่ทำแบบสอบถาม',
                    'field_type': 'date_thai',
                    'date_format': 'official',
                    'x_mm': 115.0,
                    'y_mm': 34.0,
                    'width_mm': 75.0,
                    'height_mm': 8.0,
                    'font_size': 16.0,
                    'font_bold': False,
                    'align': 'right',
                    'default_value': '2026-10-28',
                    'printable': True,
                },
                {
                    'id': 'sv_respondent',
                    'key': 'respondent_name',
                    'label': 'ชื่อ-นามสกุล ผู้ประเมิน / ผู้รับบริการ',
                    'field_type': 'text',
                    'x_mm': 25.0,
                    'y_mm': 48.0,
                    'width_mm': 105.0,
                    'height_mm': 8.0,
                    'font_size': 16.0,
                    'font_bold': True,
                    'align': 'left',
                    'default_value': 'นายอภิชาติ กันสีนวล',
                    'data_binding_key': 'full_name',
                    'printable': True,
                },
                {
                    'id': 'sv_dept',
                    'key': 'respondent_dept',
                    'label': 'หน่วยงาน / ตำแหน่ง',
                    'field_type': 'text',
                    'x_mm': 132.0,
                    'y_mm': 48.0,
                    'width_mm': 58.0,
                    'height_mm': 8.0,
                    'font_size': 16.0,
                    'font_bold': False,
                    'align': 'left',
                    'default_value': 'ประชาชนผู้มาติดต่อราชการ',
                    'data_binding_key': 'position',
                    'printable': True,
                },
                {
                    'id': 'sv_service_topic',
                    'key': 'service_topic',
                    'label': 'เรื่องที่มาติดต่อราชการ',
                    'field_type': 'text',
                    'x_mm': 25.0,
                    'y_mm': 62.0,
                    'width_mm': 165.0,
                    'height_mm': 8.0,
                    'font_size': 16.0,
                    'font_bold': False,
                    'align': 'left',
                    'default_value': 'ยื่นคำร้อง / ขอคัดถ่ายเอกสารสำนวนคดี / ติดต่อส่วนบริการประชาชน',
                    'printable': True,
                },
                {
                    'id': 'sv_chk_excellent',
                    'key': 'rate_excellent',
                    'label': 'ติ๊ก ✓ ระดับความพึงพอใจ: ดีมากที่สุด (5)',
                    'field_type': 'checkbox',
                    'draw_box': True,
                    'x_mm': 25.0,
                    'y_mm': 80.0,
                    'width_mm': 6.0,
                    'height_mm': 6.0,
                    'font_size': 16.0,
                    'font_bold': True,
                    'default_value': 'true',
                    'printable': True,
                },
                {
                    'id': 'sv_lbl_excellent',
                    'key': 'lbl_excellent',
                    'label': '[ข้อความ] ดีมากที่สุด (5 คะแนน)',
                    'field_type': 'static_text',
                    'x_mm': 34.0,
                    'y_mm': 79.5,
                    'width_mm': 65.0,
                    'height_mm': 8.0,
                    'font_size': 16.0,
                    'font_bold': False,
                    'align': 'left',
                    'default_value': 'พึงพอใจในระดับดีมากที่สุด (5 คะแนน)',
                    'printable': True,
                },
                {
                    'id': 'sv_chk_good',
                    'key': 'rate_good',
                    'label': 'ติ๊ก ✓ ระดับความพึงพอใจ: ดี (4)',
                    'field_type': 'checkbox',
                    'draw_box': True,
                    'x_mm': 105.0,
                    'y_mm': 80.0,
                    'width_mm': 6.0,
                    'height_mm': 6.0,
                    'font_size': 16.0,
                    'font_bold': True,
                    'default_value': 'false',
                    'printable': True,
                },
                {
                    'id': 'sv_lbl_good',
                    'key': 'lbl_good',
                    'label': '[ข้อความ] ดี (4 คะแนน)',
                    'field_type': 'static_text',
                    'x_mm': 114.0,
                    'y_mm': 79.5,
                    'width_mm': 65.0,
                    'height_mm': 8.0,
                    'font_size': 16.0,
                    'font_bold': False,
                    'align': 'left',
                    'default_value': 'พึงพอใจในระดับดี (4 คะแนน)',
                    'printable': True,
                },
                {
                    'id': 'sv_comment',
                    'key': 'comment_text',
                    'label': 'ข้อเสนอแนะเพิ่มเติม',
                    'field_type': 'multiline',
                    'draw_border': True,
                    'x_mm': 25.0,
                    'y_mm': 98.0,
                    'width_mm': 165.0,
                    'height_mm': 35.0,
                    'font_size': 16.0,
                    'font_bold': False,
                    'align': 'left',
                    'default_value': 'เจ้าหน้าที่ให้บริการด้วยความสุภาพ รวดเร็ว และให้คำแนะนำชัดเจนดีมาก',
                    'printable': True,
                },
            ],
        }
    )

    print("5. Registering court_form in Central Portal (PortalApp & UserAppPermission)...")
    app_obj, _ = PortalApp.objects.update_or_create(
        code='court_form',
        defaults={
            'name': 'ระบบออกแบบและจัดพิมพ์แบบฟอร์มอัจฉริยะ (Court Form Studio)',
            'description': 'ออกแบบและสั่งพิมพ์แบบฟอร์มหลายขนาด (A4, A5, ซองจดหมาย, สมุดเช็ค) ขยับตำแหน่งสดบนหน้าจอ ดึงข้อมูลจากระบบ และบันทึก PDF/รูปภาพ พร้อมระบบ Audit Log',
            'icon': 'print',
            'color': '#00897B',
            'url': 'http://localhost:8007/',
            'badge_key': '',
            'system_type': 'form',
            'is_active': True,
            'sort_order': 7,
        }
    )
    # ให้สิทธิ์ผู้ใช้งานทุกคนที่ active มองเห็นและเข้าใช้งานได้ โดย Admin ได้ app_role='admin'
    for u in User.objects.filter(is_active=True):
        is_adm = u.is_superuser or u.role == 'admin' or getattr(u, 'is_court_admin', False) or u.username in ('root', 'beebee')
        UserAppPermission.objects.update_or_create(
            user=u,
            app=app_obj,
            defaults={
                'can_view': True,
                'can_access': True,
                'app_role': 'admin' if is_adm else 'user',
                'sub_roles': [],
            }
        )

    print("Seed completed successfully!")


if __name__ == '__main__':
    seed_all()
