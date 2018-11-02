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
INDEX_OUTPUT := index.xml index.html admin.rxl admin.html external.rxl external.html

all: _site

clean:
	rm -f $(INDEX_OUTPUT) csd/*.yaml csd/*.rxl .tmp.xml csd.rxl
	rm -rf *_images

_site: _data
	bundle exec jekyll build

_data: _data/admin.yaml _data/standards.yaml

dist-clean: clean
	rm -f $(CSD_HTML) $(CSD_PDF) $(CSD_DOC) $(CSD_RXL) $(CSD_YAML)
	rm -rf _site _data/* admin external

# index.xml: csd.rxl external.rxl admin.rxl
# 	cp -a external/*.rxl csd/; \
# 	bundle exec relaton concatenate \
# 	  -t $(CSD_REGISTRY_NAME) \
# 		-g $(NAME_ORG) \
# 	  csd/ $@

$(CSD_HTML) $(CSD_PDF) $(CSD_DOC) $(CSD_RXL):
	bundle exec metanorma -t csd -R $(basename $@).rxl -x html,pdf,doc,xml $(basename $@).xml

_data/standards.yaml: standards csd.raw.rxl
	bundle exec relaton xml2yaml standards.rxl
	mv standards.yaml _data/standards.yaml

_data/%.yaml: %
	bundle exec relaton concatenate \
	  -t $(CSD_REGISTRY_NAME) \
		-g $(NAME_ORG) \
	  $</ $(patsubst %.yaml,%.xml,$(notdir $@))
	bundle exec relaton xml2yaml $(patsubst %.yaml,%.xml,$(notdir $@))
	mv $(patsubst %.xml,%.yaml,$(notdir $@)) _data/

standards: csd.raw.rxl external
	mkdir -p standards
	cp -a csd/* external/* standards/
	bundle exec relaton concatenate \
	  -t $(CSD_REGISTRY_NAME) \
		-g $(NAME_ORG) \
	  standards/ standards.rxl

admin/ admin.rxl admin/%.rxl: admin.raw.yaml
	bundle exec relaton yaml2xml \
		-x rxl \
		-o admin \
		$^

external/ external.rxl external/%.rxl: external.raw.yaml
	bundle exec relaton yaml2xml \
		-x rxl \
		-o external \
		$^

csd.raw.rxl: $(CSD_RXL)
	bundle exec relaton concatenate \
	  -t $(CSD_REGISTRY_NAME) \
		-g $(NAME_ORG) \
	  csd/ $@


# This empty target is necessary so that make detects changes in relaton-ext.yaml
%.yaml:

# %.html: %.rxl
# 	bundle exec relaton xml2html $^ $(INDEX_CSS) templates

# 	#docker run -v "$$(pwd)":/metanorma/ ribose/metanorma -t csd -x html,pdf $<

serve:
	bundle exec jekyll serve

.PHONY: bundle all open serve dist-clean clean
