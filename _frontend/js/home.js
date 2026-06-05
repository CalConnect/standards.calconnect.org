(function() {
  'use strict';

  initGlobalSearch();
  initCardAnimations();

  function initGlobalSearch() {
    var input = document.getElementById('global-search');
    var box = document.getElementById('global-search-results');
    if (!input || !box) return;

    var data = null;
    var src = document.getElementById('doc-index');
    if (src) { try { data = JSON.parse(src.textContent); } catch(e) { data = []; } }

    var activeIdx = -1;
    var timer;

    input.addEventListener('input', function() {
      clearTimeout(timer);
      timer = setTimeout(doSearch, 150);
    });

    input.addEventListener('focus', function() {
      if (input.value.trim()) doSearch();
    });

    document.addEventListener('click', function(e) {
      if (!input.contains(e.target) && !box.contains(e.target)) close();
    });

    input.addEventListener('keydown', function(e) {
      var items = box.querySelectorAll('.gsr');
      if (e.key === 'ArrowDown') {
        e.preventDefault();
        activeIdx = Math.min(activeIdx + 1, items.length - 1);
        highlight(items);
      } else if (e.key === 'ArrowUp') {
        e.preventDefault();
        activeIdx = Math.max(activeIdx - 1, -1);
        highlight(items);
      } else if (e.key === 'Enter' && activeIdx >= 0 && items[activeIdx]) {
        window.location = items[activeIdx].href;
      } else if (e.key === 'Escape') {
        close();
        input.blur();
      }
    });

    document.addEventListener('keydown', function(e) {
      if (e.key === '/' && !['INPUT','TEXTAREA','SELECT'].includes(document.activeElement.tagName)) {
        e.preventDefault();
        input.focus();
      }
    });

    function doSearch() {
      var q = input.value.trim().toLowerCase();
      if (!q || !data) { close(); return; }
      var hits = data.filter(function(d) {
        return (d.id || '').toLowerCase().indexOf(q) !== -1 ||
               (d.title || '').toLowerCase().indexOf(q) !== -1;
      }).slice(0, 8);

      if (!hits.length) {
        box.innerHTML = '<div class="gs-empty">No documents match &ldquo;' + esc(q) + '&rdquo;</div>';
      } else {
        box.innerHTML = hits.map(function(d) {
          var href = d.has_html ? '/docs/' + d.html_path : '/' + typeSlug(d) + '/';
          return '<a href="' + href + '" class="gsr">' +
            '<span class="gsr-id">' + esc(d.id) + '</span>' +
            '<span class="gsr-title">' + esc(trunc(d.title, 50)) + '</span>' +
            '<span class="gsr-meta">' +
              '<span class="gsr-type" style="background:var(--color-doctype-' + esc(d.doctype_class || '') + ')">' + esc(d.doctype) + '</span>' +
              (d.date ? '<span class="gsr-date">' + esc(d.date.substring(0, 4)) + '</span>' : '') +
            '</span></a>';
        }).join('');
      }
      box.classList.remove('hidden');
      activeIdx = -1;
    }

    function close() { box.classList.add('hidden'); activeIdx = -1; }

    function highlight(items) {
      items.forEach(function(el, i) { el.classList.toggle('gsr-active', i === activeIdx); });
      if (activeIdx >= 0 && items[activeIdx]) items[activeIdx].scrollIntoView({ block: 'nearest' });
    }

    function esc(s) { var d = document.createElement('div'); d.textContent = s || ''; return d.innerHTML; }
    function trunc(s, n) { return s && s.length > n ? s.substring(0, n) + '…' : s; }
    function typeSlug(d) {
      return d.display_category_slug || d.doctype || '';
    }
  }

  function initCardAnimations() {
    var grid = document.querySelector('.home-categories-grid');
    if (!grid || !('IntersectionObserver' in window)) return;

    grid.classList.add('card-entrance');
    var cards = grid.querySelectorAll('.category-card');
    var obs = new IntersectionObserver(function(entries) {
      entries.forEach(function(entry) {
        if (entry.isIntersecting) {
          entry.target.classList.add('card-entered');
          obs.unobserve(entry.target);
        }
      });
    }, { threshold: 0.05 });
    cards.forEach(function(c, i) {
      c.style.setProperty('--card-delay', (i * 40) + 'ms');
      obs.observe(c);
    });
  }
})();
