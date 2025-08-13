import pytest
import requests
from .conftest import BASE_URL

pytestmark = pytest.mark.integration


def _first_embedding_model(session):
	r = session.get(f"{BASE_URL}/v1/models")
	if r.status_code != 200:
		return None
	for m in r.json().get("data", []):
		if "embed" in m["id"].lower():
			return m["id"]
	return None


def test_basic_embeddings_small(http_session):
	model = _first_embedding_model(http_session)
	if not model:
		pytest.skip("No embedding model installed")
	payload = {"model": model, "input": ["a"], "encoding_format": "float"}
	r = http_session.post(f"{BASE_URL}/v1/embeddings", json=payload)
	assert r.status_code in (200, 503)
	if r.status_code == 200:
		body = r.json()
		assert len(body["data"]) == 1
		vec = body["data"][0]["embedding"]
		assert isinstance(vec, list) and len(vec) > 0