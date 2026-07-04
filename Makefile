PYTHON ?= python3
PYTHON_BIN_DIR := $(shell $(PYTHON) -c 'import os, sys; print(os.path.dirname(sys.executable))')
CFN_LINT ?= $(PYTHON_BIN_DIR)/cfn-lint
IMAGE_NAME ?= pulsecheck
IMAGE_TAG ?= local
HOST_PORT ?= 8000

.PHONY: install syntax lint cfn-lint test run docker-build docker-run k8s-dry-run ci clean

install:
	$(PYTHON) -m pip install --upgrade pip
	$(PYTHON) -m pip install -r requirements-dev.txt

syntax:
	$(PYTHON) -m compileall -q app tests

lint:
	$(PYTHON) -m ruff check app tests

cfn-lint:
	$(CFN_LINT) cloudformation/*.yaml

test:
	$(PYTHON) -m pytest -q

run:
	$(PYTHON) -m uvicorn app.main:app --host 0.0.0.0 --port 8000 --reload

docker-build:
	docker build -t $(IMAGE_NAME):$(IMAGE_TAG) .

docker-run:
	docker run --rm -p $(HOST_PORT):8000 $(IMAGE_NAME):$(IMAGE_TAG)

k8s-dry-run:
	sed "s|IMAGE_PLACEHOLDER|example.com/pulsecheck:local|g" k8s/deployment.yaml > /tmp/pulsecheck-deployment.yaml
	kubectl apply --dry-run=client --validate=false -f k8s/namespace.yaml
	kubectl apply --dry-run=client --validate=false -f /tmp/pulsecheck-deployment.yaml
	kubectl apply --dry-run=client --validate=false -f k8s/service.yaml

ci:
	./scripts/local_pipeline.sh

clean:
	docker rm -f pulsecheck-local-pipeline >/dev/null 2>&1 || true
