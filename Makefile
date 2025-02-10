
SHELL := /bin/bash

ifdef METANORMA_DOCKER
  METANORMA_PREFIX_CMD := >&2 echo "Running via docker..."; docker run -v "$$(pwd)":/metanorma/ $(METANORMA_DOCKER)
else
  METANORMA_PREFIX_CMD := >&2 echo "Running locally..."; BUNDLE_GEMFILE=src-documents/Gemfile bundle exec
endif

.PHONY: all
## Install dependencies, build Jekyll site, then build all the documents in parallel
all: prep build-all-parallel

.PHONY: clean
## Clean up generated files
clean:
	rm -rf _site

# `bundle` command alias just for Jekyll
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
## Update Metanorma YAML file (`metanorma.source.files`) for $(doc_type)
repopulate-metanorma-yaml-$(doc_type):
	DOC_TYPE=$(doc_type) \
	DOC_CLASS=cc \
	EMPTY_ADOC=src-documents/empty_index.adoc \
		scripts/repopulate-metanorma-yaml src-documents src-documents/metanorma-$(doc_type).yml

.PHONY: build-$(doc_type)
## Build Metanorma document artifacts for $(doc_type)
build-$(doc_type):
	$(METANORMA_PREFIX_CMD) metanorma site generate \
		-o _site/$(doc_type) \
		-c ./src-documents/metanorma-$(doc_type).yml
endef

$(foreach doc_type,$(DOC_TYPES),$(eval $(DOC_TYPE_TASKS)))

.PHONY: repopulate-metanorma-yamls
## Update Metanorma YAML files (`metanorma.source.files`) for all doc types
repopulate-metanorma-yamls: $(addprefix repopulate-metanorma-yaml-,$(REPOPULATING_DOC_TYPES))

.PHONY: repopulate-metanorma-yamls-parallel
## Update Metanorma YAML files (`metanorma.source.files`) for all doc types in parallel
repopulate-metanorma-yamls-parallel:
	$(foreach doc_type,$(REPOPULATING_DOC_TYPES),make repopulate-metanorma-yaml-$(doc_type) &) wait

.PHONY: build
## Build all the documents in sequence
build: $(addprefix build-,$(DOC_TYPES))

.PHONY: build-parallel
## Build all the documents in parallel
build-parallel:
	$(foreach doc_type,$(DOC_TYPES),make build-$(doc_type) &) wait

.PHONY: build-all-parallel
## Build Jekyll, then build all the documents in parallel
build-all-parallel: _site build-parallel

.PHONY: prep
## Checkout document modules and install dependencies
prep: checkout-modules prep-jekyll prep-metanorma

.PHONY: prep-metanorma
## Install Metanorma dependencies
prep-metanorma:
	BUNDLE_GEMFILE=src-documents/Gemfile bundle install

.PHONY: prep-jekyll
## Install Jekyll dependencies
prep-jekyll:
	$(JEKYLL_BUNDLE) install

.PHONY: jekyll
## Build Jekyll site
jekyll:
	$(JEKYLL_BUNDLE) exec jekyll build

## Build Jekyll site
_site: jekyll

.PHONY: serve
## Serve Jekyll site
serve:
	$(JEKYLL_BUNDLE) exec jekyll serve

.PHONY: checkout-modules
## Initialize and checkout submodules (e.g., Metanorma documents)
checkout-modules:
	git submodule update --init

.PHONY: update-modules
## Pull latest changes from submodules (e.g., Metanorma documents)
update-modules:
	git submodule foreach git pull origin main

.PHONY: update-documents
## Update Metanorma documents
update-documents: update-modules repopulate-metanorma-yamls-parallel
