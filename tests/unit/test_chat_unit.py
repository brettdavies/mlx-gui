import pytest


@pytest.mark.asyncio
async def test_chat_text_basic(client, seed_models):
    payload = {
        "model": "stub-text",
        "messages": [{"role": "user", "content": "What is 2+2?"}],
        "max_tokens": 5,
        "temperature": 0.0,
    }
    r = await client.post("/v1/chat/completions", json=payload)
    assert r.status_code == 200
    body = r.json()
    assert body["model"] == "stub-text"
    assert body["choices"][0]["message"]["content"]
    assert body["usage"]["total_tokens"] >= 0