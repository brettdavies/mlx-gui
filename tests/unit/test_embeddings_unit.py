import pytest


@pytest.mark.asyncio
async def test_embeddings_dimensions_truncation(client, seed_models):
	payload = {"input": ["one", "two"], "model": "stub-embedding", "encoding_format": "float", "dimensions": 8}
	r = await client.post("/v1/embeddings", json=payload)
	assert r.status_code == 200
	embs = r.json()["data"]
	assert len(embs) == 2
	assert len(embs[0]["embedding"]) == 8