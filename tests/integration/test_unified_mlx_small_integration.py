import os
import pytest
import requests
from .conftest import BASE_URL

pytestmark = pytest.mark.integration


def test_health_and_models(http_session):
	r = http_session.get(f"{BASE_URL}/health", timeout=5)
	assert r.status_code == 200
	r2 = http_session.get(f"{BASE_URL}/v1/models", timeout=10)
	assert r2.status_code == 200
	assert isinstance(r2.json().get("data", []), list)


def test_small_chat_if_available(http_session):
	# Try to pick the first model and send a very small request
	models = http_session.get(f"{BASE_URL}/v1/models", timeout=10).json().get("data", [])
	if not models:
		pytest.skip("No models installed")
	model = models[0]["id"]
	payload = {"model": model, "messages": [{"role": "user", "content": "hi"}], "max_tokens": 5}
	r = http_session.post(f"{BASE_URL}/v1/chat/completions", json=payload, timeout=30)
	assert r.status_code in (200, 503, 404)


def test_small_embeddings_if_available(http_session):
	models = http_session.get(f"{BASE_URL}/v1/models", timeout=10).json().get("data", [])
	embed = next((m["id"] for m in models if "embed" in m["id"].lower()), None)
	if not embed:
		pytest.skip("No embedding model installed")
	payload = {"input": ["a"], "model": embed, "encoding_format": "float"}
	r = http_session.post(f"{BASE_URL}/v1/embeddings", json=payload, timeout=60)
	assert r.status_code in (200, 503, 404)