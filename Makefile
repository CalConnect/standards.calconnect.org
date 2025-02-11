
SHELL := /bin/bash

NAME_ORG := "CalConnect"
CSD_REGISTRY_NAME := "CalConnect Document Registry"
CANON_PUBLIC_PATH := cc
SITE_DIR := _site

BIB_OUTPUT_DIR := relaton
BIB_YAML_OUTPUT_DIR := $(BIB_OUTPUT_DIR)/yaml
BIB_XML_OUTPUT_DIR := $(BIB_OUTPUT_DIR)/rxl
BIB_OUTPUT_FORMATS := yaml rxl
BIB_OUTPUTS := $(foreach output_format,$(BIB_OUTPUT_FORMATS),$(BIB_OUTPUT_DIR)/index.$(output_format))

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
clean: clean-bib
	rm -rf $(SITE_DIR)

.PHONY: clean-bib
## Clean up generated Relaton files
clean-bib:
	rm -rf $(BIB_OUTPUT_DIR)

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
		-o $(SITE_DIR)/$(doc_type) \
		-c ./src-documents/metanorma-$(doc_type).yml
endef

$(foreach doc_type,$(DOC_TYPES),$(eval $(DOC_TYPE_TASKS)))

.PHONY: repopulate-metanorma-yamls
## Update Metanorma YAML files (`metanorma.source.files`) for all doc types
repopulate-metanorma-yamls: $(addprefix repopulate-metanorma-yaml-,$(REPOPULATING_DOC_TYPES))

.PHONY: repopulate-metanorma-yamls-parallel
## Update Metanorma YAML files (`metanorma.source.files`) for all doc types in parallel
repopulate-metanorma-yamls-parallel:
	$(foreach doc_type,$(REPOPULATING_DOC_TYPES),$(MAKE) -s repopulate-metanorma-yaml-$(doc_type) &) wait

.PHONY: build
## Build all the documents in sequence
build: $(addprefix build-,$(DOC_TYPES))

.PHONY: build-all
## Build Jekyll, then build all the documents in sequence
build-all: $(SITE_DIR) build build-relaton

.PHONY: build-parallel
## Build all the documents in parallel
build-parallel:
	$(foreach doc_type,$(DOC_TYPES),$(MAKE) -s build-$(doc_type) &) wait

.PHONY: build-all-parallel
## Build Jekyll, then build all the documents in parallel
build-all-parallel: $(SITE_DIR) build-parallel build-relaton

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
$(SITE_DIR): jekyll

.PHONY: serve
## Serve Jekyll site
serve:
	$(JEKYLL_BUNDLE) exec jekyll serve

.PHONY: build-relaton
## Build Relaton documents
build-relaton: $(SITE_DIR)/$(BIB_OUTPUT_DIR)

$(SITE_DIR)/$(BIB_OUTPUT_DIR): $(BIB_OUTPUTS)
	cp -a $(BIB_OUTPUT_DIR) $(SITE_DIR)/$(BIB_OUTPUT_DIR)

# This `.canonicalized` file is used to determine whether the artifacts have
# been canonicalized.
# It is a Makefile-only artifact.
$(SITE_DIR)/$(CANON_PUBLIC_PATH): $(SITE_DIR)/$(CANON_PUBLIC_PATH)/.canonicalized

$(SITE_DIR)/$(CANON_PUBLIC_PATH)/.canonicalized:
	$(MAKE) -s canonicalize-artifacts

$(foreach output_format,$(BIB_OUTPUT_FORMATS),$(BIB_OUTPUT_DIR)/index.$(output_format)): $(SITE_DIR)/$(CANON_PUBLIC_PATH)

$(BIB_OUTPUT_DIR):
	mkdir -p $@

define BIB_TASKS
$(BIB_OUTPUT_DIR)/index.$(output_format): $(BIB_OUTPUT_DIR)/$(output_format) | $(BIB_OUTPUT_DIR)
	$(PREFIX_CMD) relaton concatenate \
	  -t $(CSD_REGISTRY_NAME) \
		-g $(NAME_ORG) \
		-x $(output_format) \
	  $(BIB_OUTPUT_DIR)/$(output_format) $$@

$(BIB_OUTPUT_DIR)/$(output_format)/%.$(output_format): $(SITE_DIR)/$(CANON_PUBLIC_PATH)/%.$(output_format)
	@>&2 echo "copying $$^ to $$@"
	cp $$^ $$@

$(BIB_OUTPUT_DIR)/$(output_format):
	mkdir -p $$@
	while read -r f; \
	do\
		>&2 echo "copying $$$$f"; \
		cp "$$$$f" $(BIB_OUTPUT_DIR)/$(output_format); \
	done < <($(MAKE) -s list-all-$(output_format))
endef

$(foreach output_format,$(BIB_OUTPUT_FORMATS),$(eval $(BIB_TASKS)))

.PHONY: list-all-yaml
## List all RXL files from compiled Metanorma documents (assuming canonicalized file names)
list-all-yaml:
	@find $(SITE_DIR)/$(CANON_PUBLIC_PATH) -name "*.yaml" -o -name "*.yml" -type f

.PHONY: list-all-rxl
## List all RXL files from compiled Metanorma documents (assuming canonicalized file names)
list-all-rxl:
	@find $(SITE_DIR)/$(CANON_PUBLIC_PATH) -name "*.rxl" -type f

# Currently, the `canonicalize-artifacts` target is not amenable to parallelization,
# due to the fact that each process has the potential to modify the same files
# (e.g., when HTML links are updated to use the canonicalized paths).
.PHONY: canonicalize-artifacts
## Canonicalize path names for Metanorma artifacts in sequence
canonicalize-artifacts:
	@if [ ! -f $(SITE_DIR)/$(CANON_PUBLIC_PATH)/.canonicalized ]; then \
		$(foreach doc_type,$(DOC_TYPES),\
	PUBLIC_PATH=$(CANON_PUBLIC_PATH) SITE_SUB_DIR=$(doc_type) scripts/canonicalize-document-paths;) \
	fi
	touch $(SITE_DIR)/$(CANON_PUBLIC_PATH)/.canonicalized

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
