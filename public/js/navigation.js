/**
 * Navigation Script
 * Handles mobile menu toggle, desktop dropdown, and active state highlighting
 */

(function() {
  'use strict';

  function initMobileMenu() {
    var toggle = document.getElementById('mobile-menu-toggle');
    var menu = document.getElementById('mobile-menu');
    if (!toggle || !menu) return;

    var closed = toggle.querySelector('.menu-closed');
    var open = toggle.querySelector('.menu-open');

    toggle.addEventListener('click', function() {
      var expanded = toggle.getAttribute('aria-expanded') === 'true';
      toggle.setAttribute('aria-expanded', !expanded);
      menu.classList.toggle('hidden', expanded);
      if (closed) closed.classList.toggle('hidden', !expanded);
      if (open) open.classList.toggle('hidden', expanded);
    });
  }

  function initDesktopDropdown() {
    var wraps = document.querySelectorAll('.nav-dropdown-wrap');
    wraps.forEach(function(wrap) {
      var btn = wrap.querySelector('.nav-dropdown-trigger');
      var dd = wrap.querySelector('.nav-dropdown');
      if (!btn || !dd) return;

      btn.addEventListener('click', function(e) {
        e.stopPropagation();
        var open = btn.getAttribute('aria-expanded') === 'true';
        btn.setAttribute('aria-expanded', !open);
        dd.classList.toggle('active', !open);
      });
    });
    document.addEventListener('click', function() {
      wraps.forEach(function(wrap) {
        var btn = wrap.querySelector('.nav-dropdown-trigger');
        var dd = wrap.querySelector('.nav-dropdown');
        if (btn) btn.setAttribute('aria-expanded', 'false');
        if (dd) dd.classList.remove('active');
      });
    });
  }

  function initActiveNav() {
    var path = window.location.pathname.replace(/\/$/, '');

    document.querySelectorAll('#nav-header a[href]').forEach(function(link) {
      var href = link.getAttribute('href').replace(/\/$/, '');
      if (href === path || (path === '' && href === '')) {
        link.classList.add('nav-active');
      }
    });

    document.querySelectorAll('#mobile-menu a[href]').forEach(function(link) {
      var href = link.getAttribute('href').replace(/\/$/, '');
      if (href === path) link.classList.add('nav-active');
    });
  }

  document.addEventListener('DOMContentLoaded', function() {
    initMobileMenu();
    initDesktopDropdown();
    initActiveNav();
  });
})();
