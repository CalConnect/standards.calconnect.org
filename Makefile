CSD_INPUT_DIR := _input/csd
CSD_OUTPUT_DIR := csd
CSD_SRC  := $(wildcard $(CSD_INPUT_DIR)/*.xml)
BIB_OUTPUT_DIR := bib
BIB_CSD_YAML := $(addprefix bib/,$(patsubst %.xml,%.rxl,$(notdir $(CSD_SRC))))
CSD_BASENAMES := $(basename $(CSD_SRC))
CSD_OUTPUT_DIRS := $(patsubst $(CSD_INPUT_DIR)/%,$(CSD_OUTPUT_DIR)/%,$(CSD_BASENAMES))
CSD_OUTPUT_XML := $(addsuffix .xml,$(CSD_OUTPUT_DIRS))
CSD_OUTPUT_HTML := $(patsubst %.xml,%.html,$(CSD_OUTPUT_XML))
CSD_OUTPUT_PDF := $(patsubst %.xml,%.pdf,$(CSD_OUTPUT_XML))
CSD_OUTPUT_DOC := $(patsubst %.xml,%.doc,$(CSD_OUTPUT_XML))
CSD_OUTPUT_RXL := $(patsubst %.xml,%.rxl,$(CSD_OUTPUT_XML))

SHELL := /bin/bash

NAME_ORG := "CalConnect : The Calendaring and Scheduling Consortium"
CSD_REGISTRY_NAME := "CalConnect Document Registry: Standards"
ADMIN_REGISTRY_NAME := "CalConnect Document Registry: Administrative Documents"
INDEX_OUTPUT := index.xml admin.rxl external.rxl
RXL_COL_OUTPUT := $(wildcard _input/*.rxl) _input/csd.yaml bib/csd.rxl bib/admin.rxl bib/external.rxl
MN_ARTIFACTS := .tmp.xml *_images

all: _documents $(CSD_OUTPUT_HTML)

clean:
	rm -f $(INDEX_OUTPUT)
	rm -rf _site _documents $(RXL_COL_OUTPUT)
	rm -rf $(MN_ARTIFACTS)
	rm -rf $(BIB_OUTPUT_DIR)

build-csd: $(CSD_OUTPUT_HTML)

clean-csd:
	rm -rf $(CSD_OUTPUT_DIR)

_site: all
	bundle exec jekyll build

distclean: clean clean-csd

$(CSD_OUTPUT_DIR)/images:
	mkdir -p $@
	cp -a $(CSD_INPUT_DIR)/images/* $@

# Make collection YAML files into adoc files
_documents: _input/csd.yaml bib bib/csd.rxl bib/admin.rxl bib/external.rxl
	mkdir -p $@
	for filename in bib/*.yaml; do \
		FN=$${filename##*/}; \
		$(MAKE) $@/$${FN//yaml/adoc}; \
	done

_documents/%.adoc: bib/%.yaml
	cp $< $@ && \
	echo "---" >> $@;

serve:
	bundle exec jekyll serve

$(BIB_OUTPUT_DIR):
	mkdir -p $@

_input/csd.rxl: $(CSD_OUTPUT_RXL)
	bundle exec relaton concatenate \
	  -t $(CSD_REGISTRY_NAME) \
		-g $(NAME_ORG) \
	  $(CSD_OUTPUT_DIR) $@; \
	sed -i '' 's+$(CSD_INPUT_DIR)+csd+g' $@

_input/csd.yaml: _input/csd.rxl
	bundle exec relaton xml2yaml $<

$(BIB_OUTPUT_DIR)/%.rxl: $(BIB_OUTPUT_DIR) _input/%.yaml
	bundle exec relaton yaml2xml \
		-x rxl \
		-o $(BIB_OUTPUT_DIR) \
		$(word 2,$^); \
	bundle exec relaton xml2yaml \
		-o $(BIB_OUTPUT_DIR) \
		$(patsubst %.yaml,%.rxl,$(word 2,$^));

# TODO: remove the "/images" part once our Metanorma XML can embed all images
$(CSD_OUTPUT_DIR)/%.html $(CSD_OUTPUT_DIR)/%.pdf $(CSD_OUTPUT_DIR)/%.doc $(CSD_OUTPUT_DIR)/%.rxl $(CSD_OUTPUT_DIR)/%.xml: $(CSD_OUTPUT_DIR)/images
	cp $(CSD_INPUT_DIR)/$(notdir $*).xml $(CSD_OUTPUT_DIR) && \
	cd $(CSD_OUTPUT_DIR) && \
	bundle exec metanorma -t csd -R $*.rxl -x html,pdf,doc,xml $*.xml

# This empty target is necessary so that make detects changes in _input/*.yaml
_input/%.yaml:


update:
	git pull origin master
	git submodule update --init

update-all: update
	git submodule foreach git pull origin master

.PHONY: bundle all open serve clean clean-csd build-csd update update-all

