---
layout: page
title: "CalConnect Document Registry: Administrative Documents"
parent: "/"
---
{% for document in site.data.admin.root.items %}
{% assign depth = "3" %}
{% include document.html %}
{% endfor %}
