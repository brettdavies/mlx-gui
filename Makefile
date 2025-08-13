PYTEST=pytest

.PHONY: test unit integration lint fmt

unit:
	$(PYTEST) tests/unit -q

integration:
	$(PYTEST) tests/integration -m integration -q

test:
	$(PYTEST) -q

lint:
	ruff check .

fmt:
	black .