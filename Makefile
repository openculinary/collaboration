.PHONY: build lint tests

SERVICE=$(shell basename $(shell git rev-parse --show-toplevel))
REGISTRY=registry.openculinary.org
PROJECT=reciperadar

IMAGE_NAME=${REGISTRY}/${PROJECT}/${SERVICE}
IMAGE_COMMIT := $(shell git rev-parse --short HEAD)
IMAGE_TAG := $(strip $(if $(shell git status --porcelain --untracked-files=no), latest, ${IMAGE_COMMIT}))

build: image

deploy:
	kubectl apply -f k8s
	kubectl set image deployments -l app=${SERVICE} ${SERVICE}=${IMAGE_NAME}:${IMAGE_TAG}

image:
	$(eval container=$(shell buildah from docker.io/library/node:buster))
	buildah copy $(container) 'package.json'
	# HACK: Apply workaround from npm/arborist#169 (h/t @nikolaik)
	buildah run $(container) -- mv /usr/local/lib/node_modules /usr/local/lib/node_modules.tmp --
	buildah run $(container) -- mv /usr/local/lib/node_modules.tmp /usr/local/lib/node_modules --
	# HACK: Downgrade to npm 6.x pending npm/arborist#171
	buildah run $(container) -- npm install -g npm@^6.14.8 --
	buildah run $(container) -- npm install --no-save --
	buildah config --port 8000 --env PORT=8000 --entrypoint 'npx /node_modules/y-websocket/bin/server.js' $(container)
	buildah commit --squash --rm $(container) ${IMAGE_NAME}:${IMAGE_TAG}
