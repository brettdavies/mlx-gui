import os
import pytest
import requests

try:
	import requests_cache
	HAS_CACHE = True
except Exception:
	HAS_CACHE = False

BASE_URL = os.environ.get("MLX_GUI_BASE_URL", "http://localhost:8000")


def pytest_configure(config):
	config.addinivalue_line("markers", "integration: marks tests as integration")


@pytest.fixture(scope="session")
def http_session():
	if HAS_CACHE:
		requests_cache.install_cache("hf_http_cache", backend="sqlite", expire_after=86400)
	s = requests.Session()
	yield s
	try:
		s.close()
		if HAS_CACHE:
			requests_cache.uninstall_cache()
	except Exception:
		pass