from django.contrib import admin
from formstudio.models import (
    PaperSizePreset,
    DataSourceConfig,
    FormTemplate,
    PrinterOffsetProfile,
    FormPrintLog,
)


@admin.register(PaperSizePreset)
class PaperSizePresetAdmin(admin.ModelAdmin):
    list_display = ('code', 'name', 'category', 'width_mm', 'height_mm', 'default_orientation', 'sort_order', 'is_active')


@admin.register(DataSourceConfig)
class DataSourceConfigAdmin(admin.ModelAdmin):
    list_display = ('source_code', 'name', 'is_enabled', 'same_court_only', 'active_only', 'updated_at')


@admin.register(FormTemplate)
class FormTemplateAdmin(admin.ModelAdmin):
    list_display = ('code', 'name', 'category', 'paper_preset', 'width_mm', 'height_mm', 'print_background', 'is_active', 'sort_order')


@admin.register(PrinterOffsetProfile)
class PrinterOffsetProfileAdmin(admin.ModelAdmin):
    list_display = ('name', 'offset_x_mm', 'offset_y_mm', 'user', 'is_shared')


@admin.register(FormPrintLog)
class FormPrintLogAdmin(admin.ModelAdmin):
    list_display = ('created_at', 'username', 'user_full_name', 'template_name', 'action_type', 'page_count', 'ip_address')
    list_filter = ('action_type', 'template_name')
    search_fields = ('username', 'user_full_name', 'template_name', 'summary_text')
