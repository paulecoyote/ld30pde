---
Time-stamp: <2014-08-28 04:30:14 ()>
layout: default
title: Releases
tagline: Released Versions
---

Versions built of this project.

<ul>
{% for page in site.static_files %}
{% if page.path contains 'v' and page.path contains 'index.html' %}
<li>
  <a href="{{ site.baseurl }}{{ page.path }}">{{ page.path }}</a>
</li>
{% endif %} <!-- page-category -->
{% endfor %} <!-- page -->
</ul>

Try Again ... 

<ul>
{% for page in site.pages %}
{% if page.url contains 'v' and page.url contains 'index.html' %}
<li>
  <a href="{{ site.baseurl }}{{ page.url }}">{{ page.url }}</a>
</li>
{% endif %} <!-- page-category -->
{% endfor %} <!-- page -->
</ul>

{% include footer.html %}