import mimetypes
from django.contrib import admin
from django.urls import path, include, re_path
from django.conf import settings
from django.conf.urls.static import static
from django.http import HttpResponse, Http404
from django.views.decorators.csrf import csrf_exempt

MIME_TYPE_MAP = {
    '.js': 'application/javascript',
    '.mjs': 'application/javascript',
    '.css': 'text/css',
    '.json': 'application/json',
    '.wasm': 'application/wasm',
    '.png': 'image/png',
    '.jpg': 'image/jpeg',
    '.jpeg': 'image/jpeg',
    '.gif': 'image/gif',
    '.svg': 'image/svg+xml',
    '.ico': 'image/x-icon',
    '.webp': 'image/webp',
    '.otf': 'font/otf',
    '.ttf': 'font/ttf',
    '.woff': 'font/woff',
    '.woff2': 'font/woff2',
}


@csrf_exempt
def serve_web(request, resource=""):
    flutter_dir = settings.BASE_DIR.parent / 'frontend' / 'build' / 'web'
    staticfiles_dir = settings.STATIC_ROOT

    clean_path = resource.strip('/')
    if clean_path == 'form':
        clean_path = ''
    elif clean_path.startswith('form/'):
        clean_path = clean_path[len('form/'):]

    target_file = None
    if clean_path:
        for base in (flutter_dir, staticfiles_dir):
            cand = (base / clean_path).resolve()
            if str(cand).startswith(str(base.resolve())) and cand.is_file():
                target_file = cand
                break
    else:
        for base in (flutter_dir, staticfiles_dir):
            if (base / 'index.html').is_file():
                target_file = base / 'index.html'
                break

    if target_file and target_file.is_file():
        ext = target_file.suffix.lower()
        content_type = MIME_TYPE_MAP.get(ext)
        if not content_type:
            content_type, _ = mimetypes.guess_type(str(target_file))
        if not content_type:
            content_type = 'text/html; charset=utf-8' if ext == '.html' else 'application/octet-stream'

        with open(target_file, 'rb') as f:
            response = HttpResponse(f.read(), content_type=content_type)
            response['Access-Control-Allow-Origin'] = '*'
            if ext in ('.html', '.json', '.js') or target_file.name in ('flutter_bootstrap.js', 'flutter_service_worker.js', 'main.dart.js'):
                response['Cache-Control'] = 'no-cache, no-store, must-revalidate'
            return response

    if clean_path and '.' in clean_path.split('/')[-1]:
        raise Http404(f"Asset not found: {clean_path}")

    for base in (flutter_dir, staticfiles_dir):
        idx_file = base / 'index.html'
        if idx_file.is_file():
            with open(idx_file, 'rb') as f:
                response = HttpResponse(f.read(), content_type='text/html; charset=utf-8')
                response['Cache-Control'] = 'no-cache, no-store, must-revalidate'
                return response

    return HttpResponse("""
    <!DOCTYPE html>
    <html>
    <head><meta charset="utf-8"><title>Court Smart Form & Print Studio</title></head>
    <body style="font-family:sans-serif;padding:40px;text-align:center;">
        <h1 style="color:#1565C0;">Court Smart Form & Print Studio (Port 8007)</h1>
        <p>API Server is running. <a href="/api/form/health/">Health Check</a></p>
    </body>
    </html>
    """)


urlpatterns = [
    path('admin/', admin.site.urls),
    path('api/form/', include('formstudio.urls')),
    path('form/api/form/', include('formstudio.urls')),
    path('api/', include('formstudio.urls')),
]

urlpatterns += static(settings.MEDIA_URL, document_root=settings.MEDIA_ROOT)
urlpatterns += static(settings.STATIC_URL, document_root=settings.STATIC_ROOT)
urlpatterns += [
    re_path(r'^(?P<resource>.*)$', serve_web),
]
