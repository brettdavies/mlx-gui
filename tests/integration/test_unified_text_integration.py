import pytest
import requests
from .conftest import BASE_URL

pytestmark = pytest.mark.integration


def _first_available_model(session):
	r = session.get(f"{BASE_URL}/v1/models")
	if r.status_code != 200:
		return None
	data = r.json().get("data", [])
	return data[0]["id"] if data else None


def test_text_generation_small(http_session):
	model = _first_available_model(http_session)
	if not model:
		pytest.skip("No models available")
	payload = {
		"model": model,
		"messages": [{"role": "user", "content": "2+2?"}],
		"max_tokens": 5,
		"temperature": 0.0,
	}
	r = http_session.post(f"{BASE_URL}/v1/chat/completions", json=payload)
	assert r.status_code in (200, 503)
	if r.status_code == 200:
		body = r.json()
		assert body["model"] == model
		assert body["choices"][0]["message"]["content"]
		assert body["usage"]["total_tokens"] >= 0