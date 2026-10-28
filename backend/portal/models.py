from django.conf import settings
from django.db import models


class CourtAddress(models.Model):
    house_number = models.CharField(max_length=50, blank=True, default="")
    village_no = models.CharField(max_length=50, blank=True, default="")
    building = models.CharField(max_length=150, blank=True, default="")
    soi = models.CharField(max_length=100, blank=True, default="")
    road = models.CharField(max_length=100, blank=True, default="")
    subdistrict = models.CharField(max_length=100, blank=True, default="")
    district = models.CharField(max_length=100, blank=True, default="")
    province = models.CharField(max_length=100, blank=True, default="")
    postal_code = models.CharField(max_length=10, blank=True, default="")

    class Meta:
        managed = False
        db_table = 'portal_courtaddress'

    @property
    def formatted_address(self):
        parts = []
        if self.house_number:
            parts.append(f"เลขที่ {self.house_number}")
        if self.building:
            parts.append(self.building)
        if self.village_no:
            parts.append(f"หมู่ที่ {self.village_no}")
        if self.soi:
            parts.append(f"ซอย{self.soi}")
        if self.road:
            parts.append(f"ถนน{self.road}")
        is_bkk = 'กรุงเทพ' in (self.province or '')
        if self.subdistrict:
            parts.append(f"แขวง{self.subdistrict}" if is_bkk else f"ตำบล{self.subdistrict}")
        if self.district:
            parts.append(f"เขต{self.district}" if is_bkk else f"อำเภอ{self.district}")
        if self.province:
            parts.append("กรุงเทพมหานคร" if is_bkk else f"จังหวัด{self.province}")
        if self.postal_code:
            parts.append(self.postal_code)
        return " ".join(parts).strip()


class Court(models.Model):
    code = models.CharField(max_length=20, unique=True)
    book_number = models.CharField(max_length=50, blank=True, default='')
    name = models.CharField(max_length=200)
    name_en = models.CharField(max_length=200, blank=True, default='')
    short_name = models.CharField(max_length=100, blank=True, default='')
    region = models.CharField(max_length=50, blank=True, default='')
    court_type = models.CharField(max_length=50, blank=True, default='')
    address = models.OneToOneField(CourtAddress, on_delete=models.SET_NULL, null=True, blank=True, related_name='court')
    phone = models.CharField(max_length=100, blank=True, default='')
    fax = models.CharField(max_length=100, blank=True, default='')
    email = models.CharField(max_length=150, blank=True, default='')
    website = models.CharField(max_length=255, blank=True, default='')
    is_active = models.BooleanField(default=True)

    class Meta:
        managed = False
        db_table = 'portal_court'

    @property
    def full_address(self):
        if self.address:
            return self.address.formatted_address
        return ""

    def __str__(self):
        return self.name


class PortalApp(models.Model):
    code = models.CharField(max_length=50, unique=True)
    name = models.CharField(max_length=150)
    url = models.CharField(max_length=255, blank=True)
    system_type = models.CharField(max_length=50, blank=True, default='')
    is_active = models.BooleanField(default=True)

    class Meta:
        managed = False
        db_table = 'portal_portalapp'

    def __str__(self):
        return f'{self.name} ({self.code})'


class UserAppPermission(models.Model):
    user = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.DO_NOTHING, related_name='+')
    app = models.ForeignKey(PortalApp, on_delete=models.DO_NOTHING, related_name='+')
    can_view = models.BooleanField(default=True)
    can_access = models.BooleanField(default=True)
    app_role = models.CharField(max_length=50, default='user')

    class Meta:
        managed = False
        db_table = 'portal_userapppermission'
