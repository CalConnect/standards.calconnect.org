
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

# This is used to generate `make` targets for each doc type.
DOC_TYPES := administrative standard public-review pending-publication

# Selectively define the output directory based on the doc type.
# Here, the doc type `standard` will output to `standards`, and all others will
# be left as is.
define site_output
$(if $(filter standard,$(1)),standards,$(1))
endef

define DOC_TYPE_TASKS
.PHONY: repopulate-metanorma-yaml-$(doc_type)
repopulate-metanorma-yaml-$(doc_type):
	DOC_TYPE=$(doc_type) DOC_CLASS=cc scripts/repopulate-metanorma-yaml src-documents metanorma-$(doc_type).yml

.PHONY: build-$(doc_type)
build-$(doc_type):
	$(PREFIX_CMD) metanorma site generate -o _site/$(call site_output,$(doc_type)) -c metanorma-$(doc_type).yml
endef

$(foreach doc_type,$(DOC_TYPES),$(eval $(DOC_TYPE_TASKS)))

.PHONY: repopulate-metanorma-yamls
repopulate-metanorma-yamls: $(addprefix repopulate-metanorma-yaml-,$(DOC_TYPES))

.PHONY: build-all-parallel
build-all-parallel: _site build-parallel

.PHONY: build-parallel
build-parallel:
	make build-standard & \
	make build-administrative & \
	make build-public-review & \
	make build-pending-publication & \
	wait

.PHONY: build
build: $(addprefix build-,$(DOC_TYPES))

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
