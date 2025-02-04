
SHELL := /bin/bash

ifdef METANORMA_DOCKER
  PREFIX_CMD := echo "Running via docker..."; docker run -v "$$(pwd)":/metanorma/ $(METANORMA_DOCKER)
else
  PREFIX_CMD := echo "Running locally..."; bundle exec
endif

.PHONY: all
all: prep _site

.PHONY: clean
clean:
	rm -rf _site

JEKYLL_BUNDLE = JEKYLL=1 bundle

# TODO: Use this to generate make targets for each category
CATEGORIES := admin standards

.PHONY: build-standards
build-standards:
	$(PREFIX_CMD) metanorma site generate -o _site/standards -c metanorma-standards.yml

.PHONY: build-admin
build-admin:
	$(PREFIX_CMD) metanorma site generate -o _site/administrative -c metanorma-admin.yml

.PHONY: build-all-parallel
build-all-parallel: _site build-parallel

.PHONY: build-parallel
build-parallel:
	make build-standards & \
	make build-admin & \
	wait

.PHONY: build
build: build-standards build-admin

.PHONY: prep
prep: prep-jekyll prep-metanorma

.PHONY: prep-metanorma
prep-metanorma:
	bundle install

.PHONY: prep-jekyll
prep-jekyll:
	$(JEKYLL_BUNDLE) install

.PHONY: jekyll
jekyll:
	$(JEKYLL_BUNDLE) exec jekyll build

_site: jekyll

.PHONY: serve
serve:
	$(JEKYLL_BUNDLE) exec jekyll serve

.PHONY: update-init
update-init:
	git submodule update --init

.PHONY: update-modules
update-modules:
	git submodule foreach git pull origin main
