import io
import os
import re
import base64
from datetime import datetime, date
from pathlib import Path
from decimal import Decimal, InvalidOperation

from django.conf import settings
from PIL import Image as PILImage
from reportlab.pdfgen import canvas
from reportlab.lib.units import mm
from reportlab.lib import colors
from reportlab.lib.utils import ImageReader
from reportlab.pdfbase import pdfmetrics
from reportlab.pdfbase.ttfonts import TTFont

try:
    import pymupdf as fitz
except ImportError:
    import fitz


# ==============================================================================
# 1. Font Registration & Thai Glyph Shaper (THSarabunNew)
# ==============================================================================
_FONTS_REGISTERED = False


def ensure_fonts_registered():
    global _FONTS_REGISTERED
    if _FONTS_REGISTERED:
        return

    fonts_dir = Path(settings.BASE_DIR) / 'fonts'
    regular_path = fonts_dir / 'THSarabunNew.ttf'
    bold_path = fonts_dir / 'THSarabunNew-Bold.ttf'
    italic_path = fonts_dir / 'THSarabunNew-Italic.ttf'
    bold_italic_path = fonts_dir / 'THSarabunNew-BoldItalic.ttf'

    if regular_path.exists():
        pdfmetrics.registerFont(TTFont('THSarabunNew', str(regular_path)))
    if bold_path.exists():
        pdfmetrics.registerFont(TTFont('THSarabunNew-Bold', str(bold_path)))
    if italic_path.exists():
        pdfmetrics.registerFont(TTFont('THSarabunNew-Italic', str(italic_path)))
    if bold_italic_path.exists():
        pdfmetrics.registerFont(TTFont('THSarabunNew-BoldItalic', str(bold_italic_path)))

    _FONTS_REGISTERED = True


def shape_thai(text: str) -> str:
    """
    จัดตำแหน่งสระและวรรณยุกต์ภาษาไทย (PUA Glyphs) สำหรับฟอนต์ THSarabunNew
    ป้องกันวรรณยุกต์ลอยหรือทับสระบน
    """
    if not text or not isinstance(text, str):
        return str(text or '')

    if not any('\u0e00' <= c <= '\u0e7f' for c in text):
        return text

    text = re.sub(r'([\u0e48-\u0e4c])\u0e33', lambda m: '\u0e4d' + m.group(1) + '\u0e32', text)
    text = re.sub(r'\u0e33([\u0e48-\u0e4c])', lambda m: '\u0e4d' + m.group(1) + '\u0e32', text)

    chars = list(text)
    length = len(chars)

    def is_base(c):
        return '\u0e01' <= c <= '\u0e2e'

    def is_base_asc(c):
        return c in ('\u0e1b', '\u0e1d', '\u0e1f', '\u0e2c')

    def is_base_desc(c):
        return c in ('\u0e0e', '\u0e0f')

    def is_upper(c):
        return c in ('\u0e31', '\u0e34', '\u0e35', '\u0e36', '\u0e37', '\u0e47', '\u0e4d')

    def is_lower(c):
        return c in ('\u0e38', '\u0e39', '\u0e3a')

    def is_tone(c):
        return '\u0e48' <= c <= '\u0e4c'

    out = []
    i = 0
    while i < length:
        c = chars[i]
        if c == '\u0e0d' and i + 1 < length and is_lower(chars[i + 1]):
            out.append('\uf70f')
            i += 1
            continue
        if c == '\u0e10' and i + 1 < length and is_lower(chars[i + 1]):
            out.append('\uf700')
            i += 1
            continue
        if is_lower(c) and i > 0 and is_base_desc(chars[i - 1]):
            offset = ord(c) - ord('\u0e38')
            out.append(chr(0xf718 + offset))
            i += 1
            continue
        if is_upper(c) and i > 0 and is_base_asc(chars[i - 1]):
            upper_map = {
                '\u0e31': '\uf710',
                '\u0e34': '\uf701',
                '\u0e35': '\uf702',
                '\u0e36': '\uf703',
                '\u0e37': '\uf704',
                '\u0e4d': '\uf711',
                '\u0e47': '\uf712',
            }
            out.append(upper_map.get(c, c))
            i += 1
            continue
        if is_tone(c):
            prev1 = chars[i - 1] if i > 0 else None
            prev2 = chars[i - 2] if i > 1 else None
            if prev1 and is_upper(prev1):
                if prev2 and is_base_asc(prev2):
                    offset = ord(c) - ord('\u0e48')
                    out.append(chr(0xf713 + offset))
                else:
                    out.append(c)
                i += 1
                continue
            base_char = prev1
            if prev1 and is_lower(prev1) and prev2:
                base_char = prev2
            if base_char and is_base(base_char):
                offset = ord(c) - ord('\u0e48')
                if is_base_asc(base_char):
                    out.append(chr(0xf705 + offset))
                else:
                    out.append(chr(0xf70a + offset))
                i += 1
                continue
        out.append(c)
        i += 1

    return ''.join(out)


# ==============================================================================
# 2. Thai Baht Text & Thai Date Helpers
# ==============================================================================
THAI_NUM_TEXT = ["ศูนย์", "หนึ่ง", "สอง", "สาม", "สี่", "ห้า", "หก", "เจ็ด", "แปด", "เก้า"]
THAI_UNIT_TEXT = ["", "สิบ", "ร้อย", "พัน", "หมื่น", "แสน", "ล้าน"]

THAI_MONTHS_FULL = [
    "", "มกราคม", "กุมภาพันธ์", "มีนาคม", "เมษายน", "พฤษภาคม", "มิถุนายน",
    "กรกฎาคม", "สิงหาคม", "กันยายน", "ตุลาคม", "พฤศจิกายน", "ธันวาคม"
]
THAI_MONTHS_SHORT = [
    "", "ม.ค.", "ก.พ.", "มี.ค.", "เม.ย.", "พ.ค.", "มิ.ย.",
    "ก.ค.", "ส.ค.", "ก.ย.", "ต.ค.", "พ.ย.", "ธ.ค."
]


def _convert_integer_chunk_to_thai(num_str: str) -> str:
    num_str = num_str.lstrip('0')
    if not num_str:
        return ""
    length = len(num_str)
    result = []
    for idx, ch in enumerate(num_str):
        digit = int(ch)
        pos = length - idx - 1
        if digit == 0:
            continue
        if pos == 1 and digit == 1:
            result.append("สิบ")
        elif pos == 1 and digit == 2:
            result.append("ยี่สิบ")
        elif pos == 0 and digit == 1 and length > 1:
            result.append("เอ็ด")
        else:
            result.append(THAI_NUM_TEXT[digit] + THAI_UNIT_TEXT[pos])
    return "".join(result)


def _convert_any_integer_to_thai(num: int) -> str:
    if num == 0:
        return "ศูนย์"
    s = str(num)
    chunks = []
    while s:
        chunks.append(s[-6:])
        s = s[:-6]
    parts = []
    for i in range(len(chunks) - 1, -1, -1):
        chunk_text = _convert_integer_chunk_to_thai(chunks[i])
        if chunk_text:
            parts.append(chunk_text + ("ล้าน" if i > 0 else ""))
        elif i > 0 and parts:
            parts.append("ล้าน")
    return "".join(parts)


def number_to_thai_baht_text(value, wrap_brackets: bool = False) -> str:
    """
    แปลงตัวเลขเป็นตัวอักษรจำนวนเงินภาษาไทย (เช่น 15420.50 -> หนึ่งหมื่นห้าพันสี่ร้อยยี่สิบบาทห้าสิบสตางค์)
    """
    if value is None:
        return ""
    cleaned = str(value).strip().replace(',', '').replace('฿', '').replace('บาท', '').strip()
    if not cleaned:
        return ""
    try:
        dec = Decimal(cleaned)
    except InvalidOperation:
        return str(value)

    is_neg = dec < 0
    dec = abs(dec).quantize(Decimal('0.01'))
    int_part = int(dec)
    satang_part = int((dec - Decimal(int_part)) * 100)

    if int_part == 0 and satang_part == 0:
        text = "ศูนย์บาทถ้วน"
    else:
        text = ""
        if is_neg:
            text += "ลบ"
        if int_part > 0:
            text += _convert_any_integer_to_thai(int_part) + "บาท"
        if satang_part > 0:
            text += _convert_any_integer_to_thai(satang_part) + "สตางค์"
        else:
            text += "ถ้วน"

    if wrap_brackets:
        return f"(-{text}-)"
    return text


def to_thai_digits(text: str) -> str:
    return str(text).translate(str.maketrans("0123456789", "๐๑๒๓๔๕๖๗๘๙"))


def format_thai_date(value, fmt: str = "full", thai_digits: bool = False) -> str:
    """
    แปลงวันที่ (YYYY-MM-DD หรือ DD/MM/YYYY) เป็นรูปแบบวันที่ไทย:
    - full: 28 ตุลาคม 2569
    - short: 28 ต.ค. 2569
    - official: วันที่ 28 เดือน ตุลาคม พ.ศ. 2569
    - slash: 28/10/2569
    - digits8: 28102569 (สำหรับช่องวันที่ 8 หลักบนเช็คธนาคาร)
    """
    if not value:
        return ""
    s = str(value).strip()
    dt = None
    for pattern in ("%Y-%m-%d", "%d/%m/%Y", "%Y/%m/%d", "%d-%m-%Y"):
        try:
            dt = datetime.strptime(s, pattern).date()
            break
        except ValueError:
            continue

    if not dt:
        return to_thai_digits(s) if thai_digits else s

    year_be = dt.year + 543 if dt.year < 2400 else dt.year
    day = dt.day
    month = dt.month

    if fmt == "short":
        res = f"{day} {THAI_MONTHS_SHORT[month]} {year_be}"
    elif fmt == "official":
        res = f"วันที่ {day} เดือน {THAI_MONTHS_FULL[month]} พ.ศ. {year_be}"
    elif fmt == "slash":
        res = f"{day:02d}/{month:02d}/{year_be}"
    elif fmt == "digits8":
        res = f"{day:02d}{month:02d}{year_be}"
    else:
        res = f"{day} {THAI_MONTHS_FULL[month]} {year_be}"

    return to_thai_digits(res) if thai_digits else res


# ==============================================================================
# 3. Form PDF & Image Renderer (Millimeter Precision)
# ==============================================================================
def _parse_hex_color(hex_str: str, default=colors.black):
    if not hex_str or not isinstance(hex_str, str):
        return default
    h = hex_str.strip().lstrip('#')
    if len(h) == 6:
        try:
            r = int(h[0:2], 16) / 255.0
            g = int(h[2:4], 16) / 255.0
            b = int(h[4:6], 16) / 255.0
            return colors.Color(r, g, b)
        except Exception:
            return default
    return default


def _decode_base64_image(data_uri: str):
    if not data_uri:
        return None
    try:
        raw = data_uri
        if ',' in raw:
            raw = raw.split(',', 1)[1]
        img_bytes = base64.b64decode(raw)
        return PILImage.open(io.BytesIO(img_bytes))
    except Exception:
        return None


def resolve_field_display_value(field: dict, values: dict) -> str:
    """
    คำนวณข้อความที่จะแสดงผล/พิมพ์จริงของแต่ละฟิลด์
    รองรับฟิลด์อัตโนมัติ เช่น bahttext ที่อ้างอิงจาก source_field, currency, date_thai
    """
    key = field.get('key', '')
    ftype = field.get('field_type', 'text')
    raw_val = values.get(key)
    if raw_val is None or raw_val == '':
        raw_val = field.get('default_value', '')

    if ftype == 'bahttext':
        source_key = field.get('source_field')
        if source_key and values.get(source_key) not in (None, ''):
            wrap = bool(field.get('wrap_brackets', False))
            return number_to_thai_baht_text(values.get(source_key), wrap_brackets=wrap)
        if raw_val:
            # ถ้าระบุตัวเลขมาโดยตรงก็แปลงให้ ถ้าเป็นตัวอักษรอยู่แล้วก็ใช้เลย
            if any(ch.isdigit() for ch in str(raw_val)):
                wrap = bool(field.get('wrap_brackets', False))
                return number_to_thai_baht_text(raw_val, wrap_brackets=wrap)
            return str(raw_val)
        return ""

    if ftype == 'currency':
        if raw_val in (None, ''):
            return ""
        cleaned = str(raw_val).replace(',', '').replace('฿', '').strip()
        try:
            dec = Decimal(cleaned)
            formatted = f"{dec:,.2f}"
            prefix = field.get('prefix', '')
            suffix = field.get('suffix', '')
            return f"{prefix}{formatted}{suffix}"
        except InvalidOperation:
            return str(raw_val)

    if ftype == 'date_thai':
        date_fmt = field.get('date_format', 'full')
        use_thai_num = bool(field.get('thai_digits', False))
        return format_thai_date(raw_val, fmt=date_fmt, thai_digits=use_thai_num)

    if use_thai_num := bool(field.get('thai_digits', False)):
        return to_thai_digits(str(raw_val))

    return str(raw_val if raw_val is not None else '')


def render_form_pdf_bytes(
    width_mm: float,
    height_mm: float,
    fields_schema: list,
    records: list,
    background_image: str = "",
    print_background: bool = False,
    offset_x_mm: float = 0.0,
    offset_y_mm: float = 0.0,
) -> bytes:
    """
    เรนเดอร์แบบพิมพ์เป็นไฟล์ PDF ความแม่นยำระดับมิลลิเมตร
    รองรับทั้ง 1 หน้า และหลายหน้า (Batch / Mail Merge)
    """
    ensure_fonts_registered()

    page_w_pt = float(width_mm) * mm
    page_h_pt = float(height_mm) * mm

    buf = io.BytesIO()
    c = canvas.Canvas(buf, pagesize=(page_w_pt, page_h_pt))
    c.setTitle("Court Smart Form & Print Studio")

    bg_pil = _decode_base64_image(background_image) if (print_background and background_image) else None
    bg_reader = ImageReader(bg_pil) if bg_pil else None

    if not records:
        records = [{}]

    for rec_idx, values in enumerate(records):
        if rec_idx > 0:
            c.showPage()

        # 1. วาดภาพพื้นหลัง (ถ้าเปิด print_background)
        if bg_reader:
            c.drawImage(
                bg_reader,
                offset_x_mm * mm,
                -offset_y_mm * mm,
                width=page_w_pt,
                height=page_h_pt,
                preserveAspectRatio=False,
                mask='auto'
            )

        # 2. วาดแต่ละฟิลด์ตามพิกัด (x_mm, y_mm) จากมุมซ้ายบน (Top-Left Origin)
        for field in fields_schema:
            if not field.get('printable', True):
                continue

            ftype = field.get('field_type', 'text')
            fx_mm = float(field.get('x_mm', 0.0)) + float(offset_x_mm)
            fy_mm = float(field.get('y_mm', 0.0)) + float(offset_y_mm)
            fw_mm = float(field.get('width_mm', 60.0))
            fh_mm = float(field.get('height_mm', 10.0))
            font_size = float(field.get('font_size', 16.0))
            is_bold = bool(field.get('font_bold', False))
            align = field.get('align', 'left')
            color_hex = field.get('color', '#000000')

            font_name = 'THSarabunNew-Bold' if is_bold else 'THSarabunNew'
            if font_name not in pdfmetrics.getRegisteredFontNames():
                font_name = 'Helvetica-Bold' if is_bold else 'Helvetica'

            c.setFont(font_name, font_size)
            stroke_color = _parse_hex_color(color_hex, colors.black)
            c.setFillColor(stroke_color)
            c.setStrokeColor(stroke_color)

            key = field.get('key', '')
            raw_val = values.get(key, field.get('default_value', ''))

            # กรณีเส้นขีดคร่อมเช็ค A/C PAYEE ONLY
            if ftype == 'cheque_cross':
                is_checked = str(raw_val).lower() in ('true', '1', 'yes', 'y', 'on', '✓', 'ac_payee')
                if is_checked:
                    c.saveState()
                    c.setStrokeColor(_parse_hex_color(color_hex, colors.HexColor('#B71C1C')))
                    c.setFillColor(_parse_hex_color(color_hex, colors.HexColor('#B71C1C')))
                    c.setLineWidth(1.2)
                    cx = fx_mm * mm
                    cy = page_h_pt - (fy_mm * mm)
                    c.translate(cx, cy)
                    c.rotate(32)
                    c.line(0, 0, 38 * mm, 0)
                    c.line(0, -6.5 * mm, 38 * mm, -6.5 * mm)
                    c.setFont(font_name, max(10, font_size - 2))
                    cross_text = str(field.get('cross_text') or 'A/C PAYEE ONLY')
                    c.drawCentredString(19 * mm, -4.8 * mm, shape_thai(cross_text))
                    c.restoreState()
                continue

            # กรณีขีดฆ่า (เช่น ขีดฆ่าคำว่า "หรือผู้ถือ" บนเช็ค)
            if ftype == 'strike_line':
                is_checked = str(raw_val).lower() in ('true', '1', 'yes', 'y', 'on', '✓')
                if is_checked:
                    c.saveState()
                    c.setLineWidth(1.5)
                    x1 = fx_mm * mm
                    y_mid = page_h_pt - ((fy_mm + (fh_mm / 2.0)) * mm)
                    c.line(x1, y_mid, (fx_mm + fw_mm) * mm, y_mid)
                    c.restoreState()
                continue

            # กรณี Checkbox (ทำเครื่องหมายถูก ✓)
            if ftype == 'checkbox':
                is_checked = str(raw_val).lower() in ('true', '1', 'yes', 'y', 'on', '✓')
                draw_box = bool(field.get('draw_box', False))
                box_size_pt = min(fw_mm, fh_mm, 5.5) * mm
                bx = fx_mm * mm
                by = page_h_pt - (fy_mm * mm) - box_size_pt
                if draw_box:
                    c.setLineWidth(0.8)
                    c.rect(bx, by, box_size_pt, box_size_pt, stroke=1, fill=0)
                if is_checked:
                    c.saveState()
                    c.setLineWidth(1.6)
                    # วาดเครื่องหมายถูก ✓ ด้วยเส้น Vector เพื่อความคมชัดทุกเครื่องพิมพ์
                    c.line(bx + box_size_pt * 0.18, by + box_size_pt * 0.48, bx + box_size_pt * 0.42, by + box_size_pt * 0.20)
                    c.line(bx + box_size_pt * 0.42, by + box_size_pt * 0.20, bx + box_size_pt * 0.88, by + box_size_pt * 0.85)
                    c.restoreState()
                continue

            display_text = resolve_field_display_value(field, values)
            if not display_text:
                continue

            # กรณีช่องกรอกทีละหลัก (box_group เช่น รหัสไปรษณีย์ 5 ช่อง หรือเลขวันที่ 8 ช่อง)
            if ftype == 'box_group':
                spacing_mm = float(field.get('letter_spacing_mm', 5.8))
                baseline_y = page_h_pt - (fy_mm * mm) - (font_size * 0.72)
                clean_chars = [ch for ch in str(display_text) if ch.strip()]
                max_boxes = int(field.get('max_boxes', 0) or len(clean_chars))
                for idx, ch in enumerate(clean_chars[:max_boxes]):
                    char_x = (fx_mm + (idx * spacing_mm) + (spacing_mm / 2.0)) * mm
                    c.drawCentredString(char_x, baseline_y, shape_thai(ch))
                continue

            # กรณีข้อความหลายบรรทัด (multiline)
            if ftype == 'multiline' or '\n' in display_text:
                line_height_pt = font_size * float(field.get('line_height', 1.05))
                baseline_y = page_h_pt - (fy_mm * mm) - (font_size * 0.72)
                max_w_pt = fw_mm * mm
                raw_lines = str(display_text).split('\n')
                wrapped_lines = []
                for rline in raw_lines:
                    if not rline:
                        wrapped_lines.append("")
                        continue
                    # ตัดบรรทัดถ้าข้อความยาวเกินความกว้างกรอบ
                    words = rline.split(' ')
                    curr = ""
                    for w in words:
                        test_line = f"{curr} {w}".strip() if curr else w
                        if pdfmetrics.stringWidth(shape_thai(test_line), font_name, font_size) <= max_w_pt or not curr:
                            curr = test_line
                        else:
                            wrapped_lines.append(curr)
                            curr = w
                    if curr:
                        wrapped_lines.append(curr)

                for l_idx, line_str in enumerate(wrapped_lines):
                    ly = baseline_y - (l_idx * line_height_pt)
                    shaped = shape_thai(line_str)
                    if align == 'center':
                        c.drawCentredString((fx_mm + fw_mm / 2.0) * mm, ly, shaped)
                    elif align == 'right':
                        c.drawRightString((fx_mm + fw_mm) * mm, ly, shaped)
                    else:
                        c.drawString(fx_mm * mm, ly, shaped)
                continue

            # กรณีข้อความบรรทัดเดียวปกติ (text, number, currency, bahttext, date_thai, static_text)
            baseline_y = page_h_pt - (fy_mm * mm) - (font_size * 0.72)
            shaped_text = shape_thai(display_text)
            if align == 'center':
                c.drawCentredString((fx_mm + fw_mm / 2.0) * mm, baseline_y, shaped_text)
            elif align == 'right':
                c.drawRightString((fx_mm + fw_mm) * mm, baseline_y, shaped_text)
            else:
                c.drawString(fx_mm * mm, baseline_y, shaped_text)

        # กรอบตาราง/เส้นขอบของฟิลด์ถ้าตั้ง draw_border=True
        for field in fields_schema:
            if not field.get('printable', True):
                continue
            if field.get('draw_border', False):
                fx_mm = float(field.get('x_mm', 0.0)) + float(offset_x_mm)
                fy_mm = float(field.get('y_mm', 0.0)) + float(offset_y_mm)
                fw_mm = float(field.get('width_mm', 60.0))
                fh_mm = float(field.get('height_mm', 10.0))
                c.saveState()
                c.setLineWidth(0.5)
                c.setStrokeColor(colors.HexColor('#555555'))
                c.rect(
                    fx_mm * mm,
                    page_h_pt - ((fy_mm + fh_mm) * mm),
                    fw_mm * mm,
                    fh_mm * mm,
                    stroke=1,
                    fill=0
                )
                c.restoreState()

    c.save()
    return buf.getvalue()


def render_form_png_bytes(
    width_mm: float,
    height_mm: float,
    fields_schema: list,
    values: dict,
    background_image: str = "",
    print_background: bool = False,
    offset_x_mm: float = 0.0,
    offset_y_mm: float = 0.0,
    dpi: int = 300,
) -> bytes:
    """
    เรนเดอร์แบบพิมพ์เป็นไฟล์รูปภาพ PNG ความละเอียดสูง (300 DPI)
    โดยแปลงจาก PDF Engine เดียวกันเพื่อให้ตำแหน่งตรงกัน 100%
    """
    pdf_bytes = render_form_pdf_bytes(
        width_mm=width_mm,
        height_mm=height_mm,
        fields_schema=fields_schema,
        records=[values],
        background_image=background_image,
        print_background=print_background,
        offset_x_mm=offset_x_mm,
        offset_y_mm=offset_y_mm,
    )
    doc = fitz.open(stream=pdf_bytes, filetype="pdf")
    page = doc[0]
    pix = page.get_pixmap(dpi=max(96, min(int(dpi), 400)), alpha=False)
    png_bytes = pix.tobytes("png")
    doc.close()
    return png_bytes
