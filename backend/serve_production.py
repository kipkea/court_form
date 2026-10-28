import os
import sys
from pathlib import Path

current_dir = Path(__file__).resolve().parent
sys.path.insert(0, str(current_dir))

os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'config.settings')

import django
django.setup()

from config.wsgi import application

if __name__ == '__main__':
    port = int(os.environ.get('PORT', 8007))
    host = os.environ.get('HOST', '0.0.0.0')

    print('=' * 68)
    print('  Starting Court Smart Form & Print Studio (Port 8007)')
    print(f'  Access URL: http://localhost:{port} or http://<server-ip>:{port}')
    print('  Connected to Court Central Portal & SSO (cdmc_system)')
    print('=' * 68)

    try:
        from waitress import serve
        serve(application, host=host, port=port, threads=8)
    except ImportError:
        from django.core.management import call_command
        call_command('runserver', f'{host}:{port}')
