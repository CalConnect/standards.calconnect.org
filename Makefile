BIB_OUTPUT_DIR := relaton
BIB_YAML_OUTPUT_DIR := relaton/yaml
BIB_XML_OUTPUT_DIR := relaton/xml
BIB_COLL_OUTPUT_DIR := relaton/collections
CSD_BASENAMES := $(basename $(CSD_SRC))
CSD_OUTPUT_DIRS := $(patsubst $(CSD_INPUT_DIR)/%,$(CSD_OUTPUT_DIR)/%,$(CSD_BASENAMES))
CSD_OUTPUT_XML := $(addsuffix .xml,$(CSD_OUTPUT_DIRS))
CSD_OUTPUT_HTML := $(patsubst %.xml,%.html,$(CSD_OUTPUT_XML))
CSD_OUTPUT_PDF := $(patsubst %.xml,%.pdf,$(CSD_OUTPUT_XML))
CSD_OUTPUT_DOC := $(patsubst %.xml,%.doc,$(CSD_OUTPUT_XML))
CSD_OUTPUT_RXL := $(patsubst %.xml,%.rxl,$(CSD_OUTPUT_XML))
BIB_XML_CSD_OUTPUT := $(patsubst $(CSD_OUTPUT_DIR)/%,$(BIB_XML_OUTPUT_DIR)/%,$(CSD_OUTPUT_RXL))
BIB_YAML_CSD_OUTPUT := $(patsubst $(CSD_OUTPUT_DIR)/%,$(BIB_YAML_OUTPUT_DIR)/%,$(patsubst %.rxl,%.yaml,$(CSD_OUTPUT_RXL)))

SHELL := /bin/bash

ifdef METANORMA_DOCKER
  PREFIX_CMD := echo "Running via docker..."; docker run -v "$$(pwd)":/metanorma/ $(METANORMA_DOCKER)
else
  PREFIX_CMD := echo "Running locally..."; bundle exec
endif

NAME_ORG := "CalConnect"
CSD_REGISTRY_NAME := "CalConnect Document Registry"

.PHONY: all
all: _documents $(CSD_OUTPUT_HTML) $(RELATON_INDEX_OUTPUT)

.PHONY: clean
clean:
	rm -rf _site _documents
	rm -rf $(MN_ARTIFACTS)
	rm -rf _input/*.rxl _input/csd.yaml
	rm -rf $(BIB_OUTPUT_DIR)

.PHONY: build
build:
	$(PREFIX_CMD) metanorma site generate

_site: all
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
