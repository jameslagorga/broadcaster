IMAGE_NAME := gcr.io/lagorgeous-helping-hands/broadcaster:latest
DOCKERFILE := Dockerfile
RUN_CHART := broadcaster-job.yaml

.PHONY: all build push run delete

all: build push run

build:
	docker build -t $(IMAGE_NAME) -f $(DOCKERFILE) .

push:
	docker push $(IMAGE_NAME)

apply:
	kubectl apply -f  $(RUN_CHART)

delete:
	kubectl delete -f $(RUN_CHART)
