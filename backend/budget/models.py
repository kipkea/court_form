from django.contrib.auth.models import AbstractUser
from django.db import models


class User(AbstractUser):
    role = models.CharField(max_length=15, default='user')
    title = models.CharField(max_length=50, blank=True, default='')
    department = models.CharField(max_length=150, blank=True, default='')
    position = models.CharField(max_length=150, blank=True, default='')
    seniority = models.IntegerField(default=999)
    otp_secret = models.CharField(max_length=32, blank=True, null=True)
    is_2fa_enabled = models.BooleanField(default=False)
    phone_number = models.CharField(max_length=50, blank=True, default='')
    signature = models.TextField(blank=True, null=True)
    court = models.ForeignKey('portal.Court', on_delete=models.SET_NULL, null=True, blank=True, related_name='+')
    is_court_admin = models.BooleanField(default=False)
    active_session_key = models.CharField(max_length=255, blank=True, null=True)
    session_expires_at = models.DateTimeField(blank=True, null=True)

    class Meta:
        managed = False
        db_table = 'budget_user'

    @property
    def display_name(self):
        full = f'{self.first_name} {self.last_name}'.strip()
        if full:
            return f'{self.title}{full}' if self.title else full
        return self.username

    def __str__(self):
        return self.display_name
