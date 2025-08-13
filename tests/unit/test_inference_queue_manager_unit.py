import asyncio
import pytest

from mlx_gui.inference_queue_manager import get_inference_manager, QueuedRequest
from mlx_gui.mlx_integration import GenerationConfig


@pytest.mark.asyncio
async def test_queue_status_initial(seed_models):
	manager = get_inference_manager()
	status = manager.get_queue_status("stub-text")
	assert status["model_name"] == "stub-text"
	assert status["active_requests"] == 0
	assert status["queued_requests"] == 0
	assert status["can_accept_immediate"] is True


@pytest.mark.asyncio
async def test_queue_request_processing_when_available(seed_models):
	manager = get_inference_manager()
	req = QueuedRequest(
		session_id="s1",
		model_name="stub-text",
		prompt="hello",
		config=GenerationConfig(max_tokens=1),
		priority=1,
	)
	req_id = await manager.queue_request(req)
	# Since capacity available, item should be in PROCESSING state and active count incremented
	status = manager.get_queue_status("stub-text")
	assert status["processing_requests"] >= 1 or status["active_requests"] >= 1
	assert isinstance(req_id, str) and len(req_id) > 0


@pytest.mark.asyncio
async def test_queue_request_queued_when_busy(seed_models):
	manager = get_inference_manager()
	# Simulate busy by setting active to max (1)
	manager._active_requests["stub-text"] = manager.max_concurrent_per_model
	req = QueuedRequest(
		session_id="s2",
		model_name="stub-text",
		prompt="busy",
		config=GenerationConfig(max_tokens=1),
		priority=1,
	)
	_ = await manager.queue_request(req)
	status = manager.get_queue_status("stub-text")
	assert status["queued_requests"] >= 1
	# Cleanup the busy simulation
	manager._active_requests["stub-text"] = 0


@pytest.mark.asyncio
async def test_streaming_callback_stored(seed_models):
	manager = get_inference_manager()
	cb_called = {"flag": False}

	def cb(_rid, _ok, _gen):
		cb_called["flag"] = True

	req = QueuedRequest(
		session_id="s3",
		model_name="stub-text",
		prompt="stream",
		config=GenerationConfig(max_tokens=1),
		priority=1,
		streaming=True,
		stream_callback=cb,
	)
	req_id = await manager.queue_request(req)
	# Callback should be stored pending
	assert req_id in manager._pending_callbacks