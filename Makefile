REPO    := cinnetcrash/gelidonyamr
TAG     := latest

# ─── Build all Docker images ──────────────────────────────────────────────────
.PHONY: docker-build docker-build-main docker-build-cgmlst docker-build-clair3 docker-build-poppunk docker-push docker-clean help

## Build all 4 Docker images (run this before using -profile docker)
docker-build: docker-build-main docker-build-cgmlst docker-build-clair3 docker-build-poppunk
	@echo ""
	@echo "✓ All images built. Run the pipeline with:"
	@echo "  nextflow run main.nf -profile docker --platform ont --barcode_dir /path/to/fastq_pass -c config/nextflow.config"

## Build main image (most tools)
docker-build-main:
	@echo "Building $(REPO):$(TAG) ..."
	docker build -t $(REPO):$(TAG) .

## Build chewBBACA image
docker-build-cgmlst:
	@echo "Building $(REPO)-cgmlst:$(TAG) ..."
	docker build -f docker/Dockerfile.cgmlst -t $(REPO)-cgmlst:$(TAG) .

## Build Clair3 image
docker-build-clair3:
	@echo "Building $(REPO)-clair3:$(TAG) ..."
	docker build -f docker/Dockerfile.clair3 -t $(REPO)-clair3:$(TAG) .

## Build PopPUNK image
docker-build-poppunk:
	@echo "Building $(REPO)-poppunk:$(TAG) ..."
	docker build -f docker/Dockerfile.poppunk -t $(REPO)-poppunk:$(TAG) .

## Push all images to Docker Hub (requires docker login)
docker-push:
	docker push $(REPO):$(TAG)
	docker push $(REPO)-cgmlst:$(TAG)
	docker push $(REPO)-clair3:$(TAG)
	docker push $(REPO)-poppunk:$(TAG)

## Remove all locally built images
docker-clean:
	docker rmi -f $(REPO):$(TAG) $(REPO)-cgmlst:$(TAG) $(REPO)-clair3:$(TAG) $(REPO)-poppunk:$(TAG) 2>/dev/null || true

## Show this help
help:
	@echo "GelidonyAMR Docker targets:"
	@grep -E '^##' Makefile | sed 's/## /  make /' | sed 's/^  make \([a-z-]*\):/  make \1 —/'
