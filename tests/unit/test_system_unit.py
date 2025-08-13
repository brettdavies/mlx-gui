import pytest


@pytest.mark.asyncio
async def test_system_status(client):
	r = await client.get("/v1/system/status")
	assert r.status_code == 200
	body = r.json()
	assert body["status"] == "running"
	assert "system" in body and "model_manager" in body


@pytest.mark.asyncio
async def test_models_list_with_seed(client, seed_models):
	r = await client.get("/v1/models")
	assert r.status_code == 200
	data = r.json()["data"]
	assert any(m["id"] == "stub-text" for m in data)
	assert any(m["id"] == "stub-embedding" for m in data)


@pytest.mark.asyncio
async def test_manager_models_internal(client, seed_models):
	r = await client.get("/v1/manager/models")
	assert r.status_code == 200
	body = r.json()
	assert isinstance(body.get("models"), list)
	assert any(m.get("name") == "stub-vision" for m in body["models"]) 


@pytest.mark.asyncio
async def test_settings_roundtrip(client):
	# Fetch current settings
	r1 = await client.get("/v1/settings")
	assert r1.status_code == 200
	before = r1.json()
	# Update a known setting
	key = "log_level"
	new_value = "DEBUG" if before.get(key) != "DEBUG" else "INFO"
	r2 = await client.put(f"/v1/settings/{key}", json={"value": new_value})
	assert r2.status_code == 200
	assert r2.json()["value"] == new_value
	# Verify persisted
	r3 = await client.get("/v1/settings")
	assert r3.json().get(key) == new_value