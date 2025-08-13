import pytest
from .conftest import BASE_URL
from .helpers import pick_or_install_model

pytestmark = pytest.mark.integration


def test_text_generation_small(http_session):
	model = pick_or_install_model(http_session, "text")
	if not model:
		pytest.skip("No compatible text model available")
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