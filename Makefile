
SHELL := /bin/bash

ifdef METANORMA_DOCKER
  PREFIX_CMD := echo "Running via docker..."; docker run -v "$$(pwd)":/metanorma/ $(METANORMA_DOCKER)
else
  PREFIX_CMD := echo "Running locally..."; BUNDLE_GEMFILE=src-documents/Gemfile bundle exec
endif

.PHONY: all
all: prep _site

.PHONY: clean
clean:
	rm -rf _site

JEKYLL_BUNDLE = bundle

# This is used to generate `metanorma.source.files` for each doc type,
# which is the same as `DOC_TYPES` except for `public-review` and
# `pending-publication`.
REPOPULATING_DOC_TYPES := \
	administrative \
	standard \
	report \
	directive \
	specification \
	advisory \
	amendment \
	technical-corrigendum \
	guide \



# This is used to generate `make` targets for each doc type.
DOC_TYPES := \
	$(REPOPULATING_DOC_TYPES) \
	public-review \
	pending-publication \



define DOC_TYPE_TASKS
.PHONY: repopulate-metanorma-yaml-$(doc_type)
repopulate-metanorma-yaml-$(doc_type):
	DOC_TYPE=$(doc_type) \
	DOC_CLASS=cc \
	EMPTY_ADOC=src-documents/empty_index.adoc \
		scripts/repopulate-metanorma-yaml src-documents src-documents/metanorma-$(doc_type).yml

.PHONY: build-$(doc_type)
build-$(doc_type):
	$(PREFIX_CMD) metanorma site generate -o _site/$(doc_type) -c ./src-documents/metanorma-$(doc_type).yml
endef

$(foreach doc_type,$(DOC_TYPES),$(eval $(DOC_TYPE_TASKS)))

.PHONY: repopulate-metanorma-yamls
repopulate-metanorma-yamls: $(addprefix repopulate-metanorma-yaml-,$(REPOPULATING_DOC_TYPES))

.PHONY: build-all-parallel
build-all-parallel: _site build-parallel

.PHONY: build-parallel
build-parallel:
	$(foreach doc_type,$(DOC_TYPES),make build-$(doc_type) &) wait

.PHONY: build
build: $(addprefix build-,$(DOC_TYPES))

.PHONY: prep
prep: prep-jekyll prep-metanorma

.PHONY: prep-metanorma
prep-metanorma:
	BUNDLE_GEMFILE=src-documents/Gemfile bundle install

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
