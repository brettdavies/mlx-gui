import pytest


@pytest.mark.asyncio
async def test_embeddings_float_encoding(client, seed_models):
    payload = {"input": ["hello", "world"], "model": "stub-embedding", "encoding_format": "float"}
    r = await client.post("/v1/embeddings", json=payload)
    assert r.status_code == 200
    body = r.json()
    assert body["model"] == "stub-embedding"
    assert isinstance(body["data"], list) and len(body["data"]) == 2
    assert isinstance(body["data"][0]["embedding"], list)
    assert body["usage"]["total_tokens"] >= 0


@pytest.mark.asyncio
async def test_embeddings_base64_encoding(client, seed_models):
    payload = {"input": "base64 please", "model": "stub-embedding", "encoding_format": "base64"}
    r = await client.post("/v1/embeddings", json=payload)
    assert r.status_code == 200
    emb = r.json()["data"][0]["embedding"]
    assert isinstance(emb, str) and len(emb) > 0