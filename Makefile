CSD_SRC  := $(wildcard csd/*.xml)
CSD_HTML := $(patsubst %.xml,%.html,$(CSD_SRC))
CSD_PDF  := $(patsubst %.xml,%.pdf,$(CSD_SRC))
CSD_DOC  := $(patsubst %.xml,%.doc,$(CSD_SRC))
CSD_RXL  := $(patsubst %.xml,%.rxl,$(CSD_SRC))
# RELATON_CSD_RXL := $(addprefix relaton-csd/, $(notdir $(CSD_SRC)))

SHELL := /bin/bash

INDEX_CSS := templates/index-style.css
INDEX_OUTPUT := index.xml index.html

all: $(CSD_HTML) $(CSD_PDF) $(CSD_DOC) $(INDEX_OUTPUT)

clean:
	rm -f $(INDEX_OUTPUT)

dist-clean: clean
	rm -f $(CSD_HTML) $(CSD_PDF) $(CSD_DOC) $(CSD_RXL)
	rm -rf relaton-csd.xml relaton-ext.xml

index.html: index.xml
	bundle exec relaton-xml-html $^ $(INDEX_CSS) templates

index.xml: relaton-ext.xml relaton-csd.xml
	cp relaton-ext/*.rxl csd/; \
	bundle exec relaton-metanorma-extract \
	  -t "CalConnect Standards Registry" \
		-r "Calendaring and Scheduling Consortium" \
	  -R $@ csd

relaton-ext.xml relaton-ext/%.rxl:
	bundle exec relaton-yaml-xml -p "ext-" -R relaton-ext relaton-ext.yaml

$(CSD_HTML) $(CSD_PDF) $(CSD_DOC) $(CSD_RXL):
	bundle exec metanorma -t csd -R $(basename $@).rxl -x html,pdf,doc,xml $(basename $@).xml
	# bundle exec metanorma -t csd -R relaton-csd/$*.xml -x html,pdf,doc,xml $(word 2,$^)

relaton-csd.xml: $(CSD_RXL)
	bundle exec relaton-metanorma-extract \
	  -t "CalConnect Standards Registry" \
		-r "Calendaring and Scheduling Consortium" \
	  -R $@ csd


# $(RELATON_CSD_RXL): $(CSD_RXL) relaton-csd
# 	cp $(basename $(patsubst relaton-csd/%,$(basename $(notdir $@))/%,$@)).rxl $@

# $(RELATON_CSD_RXL): $(CSD_RXL) relaton-csd
# 	cp $(basename $(patsubst relaton-csd/%,$(basename $(notdir $@))/%,$@)).rxl $@

# %.xml %.html %.pdf %.doc: %.adoc
# 	bundle exec metanorma -t csd -x html,pdf,doc,xml $^
# 	#docker run -v "$$(pwd)":/metanorma/ ribose/metanorma -t csd -x html,pdf $<

# open:
# 	open $(HTML)

.PHONY: bundle all open
