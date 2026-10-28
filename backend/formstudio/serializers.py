from rest_framework import serializers
from formstudio.models import (
    PaperSizePreset,
    DataSourceConfig,
    FormTemplate,
    PrinterOffsetProfile,
    FormPrintLog,
)


class PaperSizePresetSerializer(serializers.ModelSerializer):
    class Meta:
        model = PaperSizePreset
        fields = '__all__'


class DataSourceConfigSerializer(serializers.ModelSerializer):
    class Meta:
        model = DataSourceConfig
        fields = '__all__'


class FormTemplateListSerializer(serializers.ModelSerializer):
    field_count = serializers.SerializerMethodField()
    has_background = serializers.SerializerMethodField()

    class Meta:
        model = FormTemplate
        fields = [
            'id', 'code', 'name', 'category', 'description',
            'paper_preset', 'width_mm', 'height_mm', 'orientation',
            'print_background', 'grid_size_mm',
            'default_offset_x_mm', 'default_offset_y_mm',
            'allowed_data_source', 'fields_schema', 'background_image',
            'is_active', 'sort_order', 'field_count', 'has_background',
            'updated_at',
        ]

    def get_field_count(self, obj):
        return len(obj.fields_schema) if isinstance(obj.fields_schema, list) else 0

    def get_has_background(self, obj):
        return bool(obj.background_image)


class FormTemplateDetailSerializer(serializers.ModelSerializer):
    class Meta:
        model = FormTemplate
        fields = '__all__'


class PrinterOffsetProfileSerializer(serializers.ModelSerializer):
    class Meta:
        model = PrinterOffsetProfile
        fields = '__all__'
        read_only_fields = ['user', 'created_at']


class FormPrintLogSerializer(serializers.ModelSerializer):
    action_display = serializers.CharField(source='get_action_type_display', read_only=True)

    class Meta:
        model = FormPrintLog
        fields = [
            'id', 'user', 'username', 'user_full_name', 'department', 'court_name',
            'template', 'template_code', 'template_name',
            'action_type', 'action_display', 'paper_size_label',
            'width_mm', 'height_mm', 'offset_x_mm', 'offset_y_mm',
            'print_background', 'page_count', 'data_source_used',
            'summary_text', 'printed_data', 'ip_address', 'user_agent',
            'created_at',
        ]
