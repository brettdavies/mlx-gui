import pytest


@pytest.mark.asyncio
async def test_chat_non_streaming(client, seed_models):
	payload = {
		"model": "stub-text",
		"messages": [{"role": "user", "content": "hello"}],
		"stream": False,
	}
	r = await client.post("/v1/chat/completions", json=payload)
	assert r.status_code == 200
	body = r.json()
	assert "choices" in body and body["choices"][0]["message"]["content"]


@pytest.mark.asyncio
async def test_chat_streaming_sse(client, seed_models):
	payload = {
		"model": "stub-text",
		"messages": [{"role": "user", "content": "stream please"}],
		"stream": True,
	}
	# For streaming, FastAPI returns an event stream; httpx AsyncClient returns raw text
	resp = await client.post("/v1/chat/completions", json=payload)
	assert resp.status_code == 200
	text = resp.text
	# Expect multiple data: lines and terminating [DONE]
	assert "data: " in text and "[DONE]" in text