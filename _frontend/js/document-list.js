(function() {
  'use strict';

  var searchInput = document.getElementById('doc-search');
  var filterContainer = document.getElementById('filter-tabs');
  var docCountEl = document.getElementById('doc-count');
  var noResults = document.getElementById('no-results');
  var sortSelect = document.getElementById('sort-select');
  var docList = document.getElementById('doc-list');

  if (!searchInput || !docList) return;

  var allCards = docList.querySelectorAll(':scope > .document, :scope > .doc-group');
  var activeFilter = 'all';

  function formatStage(s) {
    if (!s) return '';
    return s.split('-').map(function(w) { return w.charAt(0).toUpperCase() + w.slice(1); }).join(' ');
  }

  function buildFilterTabs() {
    if (!filterContainer) return;
    var stages = new Map();
    stages.set('all', allCards.length);
    allCards.forEach(function(card) {
      var s = card.getAttribute('data-stage');
      if (s) stages.set(s, (stages.get(s) || 0) + 1);
    });

    var html = '<button data-filter="all" class="filter-tab active">All <span class="filter-count">' + stages.get('all') + '</span></button>';
    var stageOrder = ['published','committee-draft','working-draft','draft-standard','final-draft','proposal','withdrawn','cancelled'];
    stageOrder.forEach(function(s) {
      if (stages.has(s)) {
        html += '<button data-filter="' + s + '" class="filter-tab">' + formatStage(s) + ' <span class="filter-count">' + stages.get(s) + '</span></button>';
      }
    });
    stages.forEach(function(count, s) {
      if (s !== 'all' && stageOrder.indexOf(s) === -1) {
        html += '<button data-filter="' + s + '" class="filter-tab">' + formatStage(s) + ' <span class="filter-count">' + count + '</span></button>';
      }
    });
    filterContainer.innerHTML = html;
    bindFilterTabs();
  }

  function bindFilterTabs() {
    var tabs = filterContainer.querySelectorAll('.filter-tab');
    tabs.forEach(function(tab) {
      tab.addEventListener('click', function() {
        tabs.forEach(function(t) { t.classList.remove('active'); });
        tab.classList.add('active');
        activeFilter = tab.getAttribute('data-filter');
        applyFilters();
      });
    });
  }

  function applyFilters() {
    var query = searchInput.value.toLowerCase().trim();
    var visibleCount = 0;

    allCards.forEach(function(card) {
      var searchText = card.getAttribute('data-search') || (card.querySelector('.doc-identifier') || {}).textContent || '';
      var stage = card.getAttribute('data-stage') || '';
      var matchSearch = !query || searchText.toLowerCase().indexOf(query) !== -1;
      var matchStage = activeFilter === 'all' || stage === activeFilter;
      var visible = matchSearch && matchStage;
      var wasHidden = card.classList.contains('hidden');
      card.classList.toggle('hidden', !visible);
      if (visible) {
        visibleCount++;
        if (wasHidden && card.animate) {
          card.animate([
            { opacity: 0, transform: 'translateY(-4px)' },
            { opacity: 1, transform: 'translateY(0)' }
          ], { duration: 200, easing: 'ease-out' });
        }
      }
    });

    if (docCountEl) docCountEl.textContent = visibleCount + ' document' + (visibleCount !== 1 ? 's' : '');
    if (noResults) noResults.classList.toggle('hidden', visibleCount > 0);
  }

  function parseDate(str) {
    if (!str) return 0;
    var d = new Date(str);
    return isNaN(d.getTime()) ? 0 : d.getTime();
  }

  function sortDocs() {
    var items = Array.prototype.slice.call(allCards);
    items.sort(function(a, b) {
      switch (sortSelect.value) {
        case 'id-asc': return (a.getAttribute('data-id') || '').localeCompare(b.getAttribute('data-id') || '');
        case 'id-desc': return (b.getAttribute('data-id') || '').localeCompare(a.getAttribute('data-id') || '');
        case 'date-desc': return parseDate(b.getAttribute('data-date')) - parseDate(a.getAttribute('data-date'));
        case 'date-asc': return parseDate(a.getAttribute('data-date')) - parseDate(b.getAttribute('data-date'));
        case 'title-asc': return (a.getAttribute('data-title') || '').localeCompare(b.getAttribute('data-title') || '');
        default: return 0;
      }
    });
    items.forEach(function(item) { docList.appendChild(item); });
  }

  function setupViewToggle() {
    var cardBtn = document.getElementById('view-cards');
    var compactBtn = document.getElementById('view-compact');
    if (!cardBtn || !compactBtn) return;

    var saved = localStorage.getItem('doc-view');
    if (saved === 'compact') {
      compactBtn.classList.add('active');
      compactBtn.setAttribute('aria-pressed', 'true');
      cardBtn.classList.remove('active');
      cardBtn.setAttribute('aria-pressed', 'false');
      docList.classList.add('compact-view');
    }

    cardBtn.addEventListener('click', function() {
      cardBtn.classList.add('active');
      cardBtn.setAttribute('aria-pressed', 'true');
      compactBtn.classList.remove('active');
      compactBtn.setAttribute('aria-pressed', 'false');
      docList.classList.remove('compact-view');
      localStorage.setItem('doc-view', 'cards');
    });

    compactBtn.addEventListener('click', function() {
      compactBtn.classList.add('active');
      compactBtn.setAttribute('aria-pressed', 'true');
      cardBtn.classList.remove('active');
      cardBtn.setAttribute('aria-pressed', 'false');
      docList.classList.add('compact-view');
      localStorage.setItem('doc-view', 'compact');
    });
  }

  function setupStickyToolbar() {
    var toolbar = document.getElementById('doc-toolbar');
    var heroSection = document.querySelector('.hero-section');
    if (!toolbar || !heroSection) return;

    var observer = new IntersectionObserver(function(entries) {
      entries.forEach(function(entry) {
        toolbar.classList.toggle('is-sticky', !entry.isIntersecting);
      });
    }, { threshold: 0 });
    observer.observe(heroSection);
  }

  // Keyboard shortcut: "/" to focus search
  document.addEventListener('keydown', function(e) {
    if (e.key === '/' && document.activeElement !== searchInput) {
      e.preventDefault();
      searchInput.focus();
    }
    if (e.key === 'Escape' && document.activeElement === searchInput) {
      searchInput.blur();
    }
  });

  // Debounced search
  var debounceTimer;
  searchInput.addEventListener('input', function() {
    clearTimeout(debounceTimer);
    debounceTimer = setTimeout(applyFilters, 150);
  });

  // Sort
  if (sortSelect) {
    var savedSort = localStorage.getItem('doc-sort');
    if (savedSort && sortSelect.querySelector('option[value="' + savedSort + '"]')) {
      sortSelect.value = savedSort;
    }
    sortSelect.addEventListener('change', function() {
      localStorage.setItem('doc-sort', sortSelect.value);
      sortDocs();
    });
  }

  // Global clearSearch
  window.clearSearch = function() {
    searchInput.value = '';
    activeFilter = 'all';
    var tabs = filterContainer.querySelectorAll('.filter-tab');
    tabs.forEach(function(t) { t.classList.remove('active'); });
    if (tabs[0]) tabs[0].classList.add('active');
    applyFilters();
  };

  // Initialize
  buildFilterTabs();
  sortDocs();
  applyFilters();
  setupViewToggle();
  setupStickyToolbar();
})();
