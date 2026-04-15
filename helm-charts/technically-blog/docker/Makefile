# HTTP Basic auth against the registry (htpasswd, etc.): export credentials before publish:
#   export REGISTRY_USER=you
#   export REGISTRY_PASSWORD=secret   # or a token the registry accepts as password
#   make publish
REGISTRY ?= registry.int.kakwalab.ovh
IMAGE ?= technically-blog
TAG ?= latest

FULL_IMAGE := $(REGISTRY)/$(IMAGE)

.PHONY: build publish

build:
	docker build -t $(FULL_IMAGE):$(TAG) .

publish: build
	@set -e; \
	if [ -n "$$REGISTRY_USER" ] && [ -n "$$REGISTRY_PASSWORD" ]; then \
		printf '%s\n' "$$REGISTRY_PASSWORD" | docker login "$(REGISTRY)" -u "$$REGISTRY_USER" --password-stdin; \
	fi
	docker push $(FULL_IMAGE):$(TAG)
