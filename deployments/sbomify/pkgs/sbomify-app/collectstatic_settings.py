import os
from pathlib import Path

BASE_DIR = Path(os.environ["SBOMIFY_BASE_DIR"])

SECRET_KEY = "collectstatic-only"
DEBUG = False

INSTALLED_APPS = [
    "django.contrib.staticfiles",
    "django_vite",
]

STATIC_URL = "static/"
STATICFILES_DIRS = [BASE_DIR / "sbomify" / "static"]
STATIC_ROOT = BASE_DIR / "staticfiles"

STORAGES = {
    "staticfiles": {
        "BACKEND": "whitenoise.storage.ManifestStaticFilesStorage",
    },
}

DJANGO_VITE = {
    "default": {
        "dev_mode": False,
        "manifest_path": str(BASE_DIR / "sbomify" / "static" / "dist" / "manifest.json"),
        "static_url_prefix": "dist/",
    }
}
