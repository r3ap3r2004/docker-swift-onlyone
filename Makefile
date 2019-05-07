PROJECT=docker-swift-onlyone-authv2-keystone
NETWORK=$(PROJECT)-net
ROOT_DIR:=$(shell dirname $(realpath $(lastword $(MAKEFILE_LIST))))

build:
	docker build . -t $(PROJECT)

run: build stop
	docker run --rm --network $(NETWORK) -p 8080:8080 -p 5000:5000 --name $(PROJECT) $(PROJECT)

shell:
	docker exec -it $(PROJECT) bash

stop:
	docker stop $(PROJECT) | true