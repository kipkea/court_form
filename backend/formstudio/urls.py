from django.urls import path, include
from rest_framework.routers import DefaultRouter
from formstudio.views import (
    HealthCheckView,
    SSOVerifyView,
    DirectLoginView,
    CurrentUserView,
    PaperSizePresetViewSet,
    FormTemplateViewSet,
    DataSourceConfigViewSet,
    BatchFileParseView,
    PrinterOffsetProfileViewSet,
    TextHelperView,
    RenderAndPrintView,
    FormPrintLogViewSet,
)

router = DefaultRouter()
router.register(r'paper-sizes', PaperSizePresetViewSet, basename='paper-sizes')
router.register(r'templates', FormTemplateViewSet, basename='templates')
router.register(r'data-sources', DataSourceConfigViewSet, basename='data-sources')
router.register(r'printer-profiles', PrinterOffsetProfileViewSet, basename='printer-profiles')
router.register(r'print-logs', FormPrintLogViewSet, basename='print-logs')

urlpatterns = [
    path('health/', HealthCheckView.as_view(), name='form-health'),
    path('auth/sso-verify/', SSOVerifyView.as_view(), name='form-sso-verify'),
    path('auth/login/', DirectLoginView.as_view(), name='form-direct-login'),
    path('auth/me/', CurrentUserView.as_view(), name='form-auth-me'),
    path('batch/parse-file/', BatchFileParseView.as_view(), name='form-batch-parse'),
    path('helpers/convert/', TextHelperView.as_view(), name='form-helpers-convert'),
    path('render/', RenderAndPrintView.as_view(), name='form-render'),
    path('', include(router.urls)),
]
