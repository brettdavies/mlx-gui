import json
import os
import time
import pytest

from .conftest import BASE_URL
from .helpers import pick_or_install_model

pytestmark = pytest.mark.integration


def test_embeddings_float(http_session):
	model_name = pick_or_install_model(http_session, "embedding")
	if not model_name:
		pytest.skip("No compatible embedding model available")
	payload = {"input": ["Hello", "World"], "model": model_name, "encoding_format": "float"}
	r = http_session.post(f"{BASE_URL}/v1/embeddings", json=payload, timeout=120)
	assert r.status_code == 200
	data = r.json()
	assert len(data["data"]) == 2
	assert isinstance(data["data"][0]["embedding"], list)


def test_embeddings_base64(http_session):
	model_name = pick_or_install_model(http_session, "embedding")
	if not model_name:
		pytest.skip("No compatible embedding model available")
	payload = {"input": "base64 string", "model": model_name, "encoding_format": "base64"}
	r = http_session.post(f"{BASE_URL}/v1/embeddings", json=payload, timeout=120)
	assert r.status_code in (200, 500)
	if r.status_code == 200:
		assert isinstance(r.json()["data"][0]["embedding"], str)