from django.db import models
from django.conf import settings


class PaperSizePreset(models.Model):
    """
    มาตรฐานขนาดกระดาษ เช่น A4, A5, ซองจดหมาย DL/C5/C4, สมุดเช็คธนาคาร ฯลฯ
    """
    code = models.CharField(max_length=50, unique=True, verbose_name="รหัสขนาดกระดาษ")
    name = models.CharField(max_length=150, verbose_name="ชื่อขนาดกระดาษ")
    category = models.CharField(
        max_length=50,
        default='STANDARD',
        verbose_name="หมวดหมู่ (STANDARD, ENVELOPE, CHEQUE, CUSTOM)"
    )
    width_mm = models.FloatField(verbose_name="ความกว้าง (มม.)")
    height_mm = models.FloatField(verbose_name="ความสูง (มม.)")
    default_orientation = models.CharField(
        max_length=20,
        default='portrait',
        verbose_name="แนวกระดาษเริ่มต้น (portrait/landscape)"
    )
    description = models.CharField(max_length=255, blank=True, default="", verbose_name="คำอธิบาย")
    sort_order = models.IntegerField(default=0)
    is_active = models.BooleanField(default=True)

    class Meta:
        db_table = 'formstudio_papersizepreset'
        ordering = ['sort_order', 'id']
        verbose_name = 'ขนาดกระดาษมาตรฐาน'
        verbose_name_plural = 'ขนาดกระดาษมาตรฐาน'

    def __str__(self):
        return f"{self.name} ({self.width_mm}x{self.height_mm} mm)"


class DataSourceConfig(models.Model):
    """
    ตั้งค่าแหล่งข้อมูลในระบบที่อนุญาตให้นำมาพิมพ์ (ควบคุมและกรองโดย Admin)
    """
    source_code = models.CharField(max_length=50, unique=True, verbose_name="รหัสแหล่งข้อมูล")
    name = models.CharField(max_length=150, verbose_name="ชื่อแหล่งข้อมูล")
    description = models.TextField(blank=True, default="", verbose_name="คำอธิบาย")
    is_enabled = models.BooleanField(default=True, verbose_name="เปิดอนุญาตให้ใช้งาน")
    same_court_only = models.BooleanField(
        default=False,
        verbose_name="กรองเฉพาะข้อมูลในสังกัดศาลเดียวกันกับผู้พิมพ์"
    )
    active_only = models.BooleanField(default=True, verbose_name="กรองเฉพาะรายการที่เปิดใช้งาน (Active)")
    filter_config = models.JSONField(default=dict, blank=True, verbose_name="เงื่อนไขการกรองเพิ่มเติม")
    exposed_fields = models.JSONField(
        default=list,
        blank=True,
        verbose_name="รายชื่อฟิลด์ที่อนุญาตให้ดึงออกมาใช้"
    )
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        db_table = 'formstudio_datasourceconfig'
        ordering = ['id']
        verbose_name = 'แหล่งข้อมูลที่อนุญาตให้นำมาพิมพ์'
        verbose_name_plural = 'แหล่งข้อมูลที่อนุญาตให้นำมาพิมพ์'

    def __str__(self):
        return f"{self.name} ({self.source_code})"


class FormTemplate(models.Model):
    """
    แม่แบบงานประจำ เช่น พิมพ์เช็คธนาคาร, จ่าหน้าซองจดหมาย, แบบสอบถาม A4, ใบสำคัญรับเงิน
    เฉพาะ Admin เป็นผู้สร้าง/แก้ไขแม่แบบหลัก ส่วนผู้ใช้ทั่วไปเลือกใช้งานและขยับตำแหน่งสดตอนพิมพ์ได้
    """
    CATEGORY_CHOICES = (
        ('CHEQUE', 'สมุดเช็ค / การเงิน'),
        ('ENVELOPE', 'ซองจดหมาย / งานสารบรรณ'),
        ('SURVEY', 'แบบสอบถาม / แบบฟอร์ม A4-A5'),
        ('OFFICIAL', 'เอกสารราชการ / ใบสำคัญ'),
        ('CUSTOM', 'งานพิมพ์ทั่วไปกำหนดเอง'),
    )

    code = models.CharField(max_length=60, unique=True, verbose_name="รหัสแม่แบบ")
    name = models.CharField(max_length=200, verbose_name="ชื่องานประจำ / แม่แบบ")
    category = models.CharField(max_length=30, choices=CATEGORY_CHOICES, default='CUSTOM', verbose_name="หมวดหมู่งาน")
    description = models.TextField(blank=True, default="", verbose_name="คำอธิบายการใช้งาน")

    paper_preset = models.CharField(max_length=50, default='A4', verbose_name="รหัสขนาดกระดาษ")
    width_mm = models.FloatField(default=210.0, verbose_name="ความกว้างกระดาษ (มม.)")
    height_mm = models.FloatField(default=297.0, verbose_name="ความสูงกระดาษ (มม.)")
    orientation = models.CharField(max_length=20, default='portrait', verbose_name="แนวกระดาษ (portrait/landscape)")

    background_image = models.TextField(
        blank=True,
        default="",
        verbose_name="ภาพพื้นหลังสำหรับทาบตำแหน่ง (Base64 Data URI)"
    )
    print_background = models.BooleanField(
        default=False,
        verbose_name="พิมพ์ภาพพื้นหลังออกทางเครื่องพิมพ์ด้วยหรือไม่"
    )
    grid_size_mm = models.FloatField(default=5.0, verbose_name="ขนาดช่องตารางช่วยจัดตำแหน่ง (มม.)")
    default_offset_x_mm = models.FloatField(default=0.0, verbose_name="ชดเชยแนวแกน X เริ่มต้น (มม.)")
    default_offset_y_mm = models.FloatField(default=0.0, verbose_name="ชดเชยแนวแกน Y เริ่มต้น (มม.)")

    allowed_data_source = models.CharField(
        max_length=50,
        blank=True,
        default="",
        verbose_name="รหัสแหล่งข้อมูลเริ่มต้น (เช่น portal_users, courts)"
    )
    fields_schema = models.JSONField(
        default=list,
        blank=True,
        verbose_name="รายการช่องข้อมูลและพิกัดบนกระดาษ (JSON Schema)"
    )

    is_active = models.BooleanField(default=True, verbose_name="เปิดใช้งาน")
    sort_order = models.IntegerField(default=0, verbose_name="ลำดับการแสดงผล")
    created_by = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name='+',
        verbose_name="ผู้สร้างแม่แบบ"
    )
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        db_table = 'formstudio_formtemplate'
        ordering = ['sort_order', 'id']
        verbose_name = 'แม่แบบงานประจำ (Form Template)'
        verbose_name_plural = 'แม่แบบงานประจำ (Form Templates)'

    def __str__(self):
        return f"{self.name} ({self.width_mm}x{self.height_mm} mm)"


class PrinterOffsetProfile(models.Model):
    """
    โปรไฟล์ตั้งค่าชดเชยระยะขอบเครื่องพิมพ์ (Printer Offset X/Y มม.)
    เผื่อเครื่องพิมพ์แต่ละเครื่องดึงซองจดหมายหรือสมุดเช็คเหลื่อมกัน
    """
    name = models.CharField(max_length=150, verbose_name="ชื่อเครื่องพิมพ์ / โปรไฟล์")
    offset_x_mm = models.FloatField(default=0.0, verbose_name="ชดเชยซ้าย-ขวา X (มม.)")
    offset_y_mm = models.FloatField(default=0.0, verbose_name="ชดเชยบน-ล่าง Y (มม.)")
    user = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        null=True,
        blank=True,
        related_name='+',
        verbose_name="เจ้าของโปรไฟล์ (เว้นว่าง = ใช้ร่วมกันทั้งระบบ)"
    )
    is_shared = models.BooleanField(default=False, verbose_name="แชร์ให้ทุกคนเลือกใช้ได้")
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        db_table = 'formstudio_printeroffsetprofile'
        ordering = ['-is_shared', 'name']

    def __str__(self):
        return f"{self.name} (X:{self.offset_x_mm:+.1f}, Y:{self.offset_y_mm:+.1f} mm)"


class FormPrintLog(models.Model):
    """
    บันทึกประวัติการพิมพ์และส่งออกเอกสารทุกครั้ง (Audit Log สำหรับ Admin ตรวจสอบ)
    """
    ACTION_CHOICES = (
        ('PRINT', 'สั่งพิมพ์ออกเครื่องพิมพ์'),
        ('EXPORT_PDF', 'บันทึกเป็นไฟล์ PDF'),
        ('EXPORT_PNG', 'บันทึกเป็นไฟล์รูปภาพ (PNG)'),
        ('BATCH_PDF', 'พิมพ์ต่อเนื่องหลายแผ่น (Batch / Mail Merge)'),
    )

    user = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name='+',
        verbose_name="ผู้สั่งพิมพ์"
    )
    username = models.CharField(max_length=150, blank=True, default="", verbose_name="Username")
    user_full_name = models.CharField(max_length=255, blank=True, default="", verbose_name="ชื่อ-สกุลผู้พิมพ์")
    department = models.CharField(max_length=150, blank=True, default="", verbose_name="กลุ่มงาน/ส่วนงาน")
    court_name = models.CharField(max_length=200, blank=True, default="", verbose_name="ชื่อศาล")

    template = models.ForeignKey(
        FormTemplate,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name='print_logs',
        verbose_name="แม่แบบงานประจำ"
    )
    template_code = models.CharField(max_length=60, blank=True, default="", verbose_name="รหัสแม่แบบ")
    template_name = models.CharField(max_length=200, blank=True, default="", verbose_name="ชื่อแม่แบบงานที่พิมพ์")

    action_type = models.CharField(max_length=30, choices=ACTION_CHOICES, default='PRINT', verbose_name="ประเภทการพิมพ์")
    paper_size_label = models.CharField(max_length=100, blank=True, default="", verbose_name="ขนาดกระดาษ")
    width_mm = models.FloatField(default=210.0)
    height_mm = models.FloatField(default=297.0)
    offset_x_mm = models.FloatField(default=0.0, verbose_name="ระยะชดเชย X (มม.)")
    offset_y_mm = models.FloatField(default=0.0, verbose_name="ระยะชดเชย Y (มม.)")
    print_background = models.BooleanField(default=False, verbose_name="พิมพ์ภาพพื้นหลังหรือไม่")
    page_count = models.IntegerField(default=1, verbose_name="จำนวนหน้าที่พิมพ์")

    data_source_used = models.CharField(max_length=100, blank=True, default="", verbose_name="แหล่งข้อมูลที่ดึงมาใช้")
    summary_text = models.TextField(blank=True, default="", verbose_name="สรุปข้อมูลสำคัญที่พิมพ์")
    printed_data = models.JSONField(
        default=dict,
        blank=True,
        verbose_name="ข้อมูลทุกช่องและพิกัดที่พิมพ์จริง (JSON)"
    )

    ip_address = models.CharField(max_length=60, blank=True, default="", verbose_name="IP Address")
    user_agent = models.CharField(max_length=255, blank=True, default="", verbose_name="อุปกรณ์/เบราว์เซอร์")
    created_at = models.DateTimeField(auto_now_add=True, verbose_name="วัน-เวลาที่พิมพ์")

    class Meta:
        db_table = 'formstudio_formprintlog'
        ordering = ['-created_at']
        verbose_name = 'ประวัติการพิมพ์แบบฟอร์ม (Print Audit Log)'
        verbose_name_plural = 'ประวัติการพิมพ์แบบฟอร์ม (Print Audit Logs)'

    def __str__(self):
        return f"[{self.created_at:%Y-%m-%d %H:%M}] {self.username} - {self.template_name} ({self.action_type})"
