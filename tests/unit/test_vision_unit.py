import base64
import pytest


def tiny_red_png_data_url() -> str:
	# 1x1 red PNG
	png_bytes = base64.b64decode(
		"iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR4nGMAAQAABQABDQottAAAAABJRU5ErkJggg=="
	)
	return "data:image/png;base64," + base64.b64encode(png_bytes).decode("utf-8")


@pytest.mark.asyncio
async def test_vision_chat_with_image(client, seed_models):
	img_url = tiny_red_png_data_url()
	payload = {
		"model": "stub-vision",
		"messages": [
			{
				"role": "user",
				"content": [
					{"type": "text", "text": "What color?"},
					{"type": "image_url", "image_url": {"url": img_url}},
				],
			}
		],
		"max_tokens": 5,
	}
	r = await client.post("/v1/chat/completions", json=payload)
	assert r.status_code == 200
	text = r.json()["choices"][0]["message"]["content"].lower()
	assert isinstance(text, str)