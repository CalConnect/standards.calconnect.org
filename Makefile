
SHELL := /bin/bash

ifdef METANORMA_DOCKER
  PREFIX_CMD := echo "Running via docker..."; docker run -v "$$(pwd)":/metanorma/ $(METANORMA_DOCKER)
else
  PREFIX_CMD := echo "Running locally..."; bundle exec
endif

.PHONY: all
all: _site

.PHONY: clean
clean:
	rm -rf _site

# TODO: Use this to generate make targets for each category
CATEGORIES := admin standards

.PHONY: build-standards
build-standards:
	$(PREFIX_CMD) metanorma site generate -o _site/documents/standards -c metanorma-standards.yml

.PHONY: build-admin
build-admin:
	$(PREFIX_CMD) metanorma site generate -o _site/documents/admin -c metanorma-admin.yml

.PHONY: build
build: build-standards build-admin

_site: build
	bundle exec jekyll build

.PHONY: distclean
distclean: clean clean-csd

.PHONY: serve
serve:
	bundle exec jekyll serve

.PHONY: update-init
update-init:
	git submodule update --init

.PHONY: update-modules
update-modules:
	git submodule foreach git pull origin master
