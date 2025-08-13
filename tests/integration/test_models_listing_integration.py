import pytest
from .conftest import BASE_URL

pytestmark = pytest.mark.integration


def test_models_list(http_session):
	r = http_session.get(f"{BASE_URL}/v1/models")
	assert r.status_code == 200
	body = r.json()
	assert "data" in body and isinstance(body["data"], list)