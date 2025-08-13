import pytest
from .conftest import BASE_URL
from .helpers import pick_or_install_model

pytestmark = pytest.mark.integration


def test_basic_embeddings_small(http_session):
	model = pick_or_install_model(http_session, "embedding")
	if not model:
		pytest.skip("No compatible embedding model available")
	payload = {"model": model, "input": ["a"], "encoding_format": "float"}
	r = http_session.post(f"{BASE_URL}/v1/embeddings", json=payload)
	assert r.status_code in (200, 503)
	if r.status_code == 200:
		body = r.json()
		assert len(body["data"]) == 1
		vec = body["data"][0]["embedding"]
		assert isinstance(vec, list) and len(vec) > 0