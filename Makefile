CSD_SRC  := $(wildcard csd/*.xml)
CSD_HTML := $(patsubst %.xml,%.html,$(CSD_SRC))
CSD_PDF  := $(patsubst %.xml,%.pdf,$(CSD_SRC))
CSD_DOC  := $(patsubst %.xml,%.doc,$(CSD_SRC))
CSD_RXL  := $(patsubst %.xml,%.rxl,$(CSD_SRC))
CSD_YAML := $(patsubst %.xml,%.yaml,$(CSD_SRC))
# RELATON_CSD_RXL := $(addprefix relaton-csd/, $(notdir $(CSD_SRC)))

SHELL := /bin/bash

NAME_ORG := "CalConnect : The Calendaring and Scheduling Consortium"
CSD_REGISTRY_NAME := "CalConnect Document Registry: Standards"
ADMIN_REGISTRY_NAME := "CalConnect Document Registry: Administrative Documents"

INDEX_CSS := templates/index-style.css
INDEX_OUTPUT := index.xml index.html admin.xml admin.html external.xml external.html

all: _site

clean:
	rm -f $(INDEX_OUTPUT) csd/*.yaml csd/*.rxl

_site: index.xml admin.xml external.xml csd.yaml
	mkdir -p _data; \
	cp -a admin.yaml external.yaml csd.yaml _data/ && \
	bundle exec jekyll build

dist-clean: clean
	rm -f $(CSD_HTML) $(CSD_PDF) $(CSD_DOC) $(CSD_RXL) $(CSD_YAML)
	rm -rf _site _data/* admin external

index.xml: csd.xml external.xml
	cp -a external/*.rxl csd/; \
	bundle exec relaton concatenate \
	  -t $(CSD_REGISTRY_NAME) \
		-g $(NAME_ORG) \
	  csd/ $@

$(CSD_HTML) $(CSD_PDF) $(CSD_DOC) $(CSD_RXL):
	bundle exec metanorma -t csd -R $(basename $@).rxl -x html,pdf,doc,xml $(basename $@).xml

csd.xml: $(CSD_RXL)
	bundle exec relaton concatenate \
	  -t $(CSD_REGISTRY_NAME) \
		-g $(NAME_ORG) \
	  csd/ $@

csd.yaml: csd.xml
	bundle exec relaton xml2yaml \
		-o csd/ \
		$<

# This empty target is necessary so that make detects changes in relaton-ext.yaml
%.yaml:

%.xml: %.yaml
	bundle exec relaton yaml2xml \
		-x rxl \
		-o $(basename $@)/ \
		$<

%.html: %.xml
	bundle exec relaton xml2html $^ $(INDEX_CSS) templates

# 	#docker run -v "$$(pwd)":/metanorma/ ribose/metanorma -t csd -x html,pdf $<

serve:
	bundle exec jekyll serve

.PHONY: bundle all open serve dist-clean clean
