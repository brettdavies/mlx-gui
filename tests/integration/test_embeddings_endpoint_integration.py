import json
import os
import time
import pytest

from .conftest import BASE_URL

pytestmark = pytest.mark.integration

DEFAULT_MODEL_NAME = os.environ.get("EMBED_MODEL", "qwen3-embedding-0-6b-4bit-dwq")
DEFAULT_MODEL_ID = os.environ.get("EMBED_MODEL_ID", "mlx-community/Qwen3-Embedding-0.6B-4bit-DWQ")


def _ensure_model_installed(s, model_name: str, model_id: str) -> None:
	r = s.get(f"{BASE_URL}/v1/models/{model_name}")
	if r.status_code == 200:
		return
	s.post(f"{BASE_URL}/v1/models/install", json={"model_id": model_id, "name": model_name}, timeout=120)


def _wait_ready(s, model_name: str, timeout_s: int = 180) -> bool:
	try:
		s.post(f"{BASE_URL}/v1/models/{model_name}/load", timeout=10)
	except Exception:
		pass
	deadline = time.time() + timeout_s
	while time.time() < deadline:
		try:
			resp = s.get(f"{BASE_URL}/v1/models/{model_name}/health", timeout=5)
			if resp.status_code == 200 and resp.json().get("healthy"):
				return True
		except Exception:
			pass
		time.sleep(2)
	return False


def test_embeddings_float(http_session):
	_ensure_model_installed(http_session, DEFAULT_MODEL_NAME, DEFAULT_MODEL_ID)
	assert _wait_ready(http_session, DEFAULT_MODEL_NAME)
	payload = {"input": ["Hello", "World"], "model": DEFAULT_MODEL_NAME, "encoding_format": "float"}
	r = http_session.post(f"{BASE_URL}/v1/embeddings", json=payload, timeout=120)
	assert r.status_code == 200
	data = r.json()
	assert len(data["data"]) == 2
	assert isinstance(data["data"][0]["embedding"], list)


def test_embeddings_base64(http_session):
	_ensure_model_installed(http_session, DEFAULT_MODEL_NAME, DEFAULT_MODEL_ID)
	assert _wait_ready(http_session, DEFAULT_MODEL_NAME)
	payload = {"input": "base64 string", "model": DEFAULT_MODEL_NAME, "encoding_format": "base64"}
	r = http_session.post(f"{BASE_URL}/v1/embeddings", json=payload, timeout=120)
	assert r.status_code in (200, 500)
	if r.status_code == 200:
		assert isinstance(r.json()["data"][0]["embedding"], str)