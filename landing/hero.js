// Hero wall: Blackcomb at work. Each card types an address into the browser's bar, loads the page, then lands one
// real feature, a different one per card: tracker blocking, reading list, read aloud, private tab, find in page.
document.addEventListener('DOMContentLoaded', function () {
  var wall = document.getElementById('bwall'); if (!wall) return;
  var still = matchMedia('(prefers-reduced-motion: reduce)').matches;
  var n = innerWidth <= 560 ? 4 : innerWidth <= 900 ? 6 : 9;
  var LOCK = '<svg viewBox="0 0 12 12"><path d="M3 5V4a3 3 0 0 1 6 0v1h.5a.5.5 0 0 1 .5.5v5a.5.5 0 0 1-.5.5h-7a.5.5 0 0 1-.5-.5v-5a.5.5 0 0 1 .5-.5zm1.5 0h3V4a1.5 1.5 0 0 0-3 0z"/></svg>';
  var SITES = [
    ['en.wikipedia.org/wiki/Blackcomb_Peak', 'Blackcomb Peak', 'Wikipedia', '12 trackers blocked'],
    ['webkit.org/blog', 'WebKit blog', 'webkit.org', 'Saved to Reading List'],
    ['news.ycombinator.com', 'Hacker News', 'news.ycombinator.com', '3 matches for "webkit"'],
    ['developer.apple.com/documentation/webkit', 'WebKit documentation', 'Apple Developer', 'Reading aloud, 6 min'],
    ['private tab', 'New private tab', 'Nothing is recorded', 'Private: nothing saved'],
    ['www.bbc.com/news', 'BBC News', 'bbc.com', '31 trackers blocked'],
    ['github.com/nulljosh/blackcomb', 'nulljosh/blackcomb', 'GitHub', 'Saved to Reading List'],
    ['www.whistlerblackcomb.com', 'Whistler Blackcomb', 'whistlerblackcomb.com', '18 trackers blocked'],
    ['en.wikipedia.org/wiki/WebKit', 'WebKit', 'Wikipedia', 'Reading aloud, 9 min']
  ];
  var el = function (t, c, x) { var e = document.createElement(t); if (c) e.className = c; if (x != null) e.textContent = x; return e; };
  var wait = function (ms) { return new Promise(function (r) { setTimeout(r, still ? 0 : ms); }); };
  for (var i = 0; i < n; i++) (function (i) {
    var a = wall.appendChild(el('div', 'bk')), bar = a.appendChild(el('div', 'bk-bar')), load = a.appendChild(el('div', 'bk-load'));
    var pg = a.appendChild(el('div', 'bk-pg')), pill = a.appendChild(el('div', 'bk-pill')), k = i;
    function play(first) {
      var s = SITES[k % SITES.length]; k += n;
      var priv = s[0] === 'private tab';
      a.className = 'bk'; bar.className = 'bk-bar' + (priv ? ' priv' : ''); bar.innerHTML = priv ? '' : LOCK;
      var url = bar.appendChild(el('span')); load.className = 'bk-load'; load.style.transform = 'scaleX(0)';
      pg.textContent = ''; pg.appendChild(el('b', '', s[1])); pg.appendChild(el('span', '', s[2])); for (var j = 0; j < 3; j++) pg.appendChild(el('i'));
      pill.textContent = s[3];
      var text = priv ? 'Private' : s[0];
      if (still || first) { url.textContent = text; load.className = 'bk-load done'; a.className = 'bk loaded done'; return wait(first ? 2600 + i * 400 : 0); }
      return text.split('').reduce(function (q, ch, c) { return q.then(function () { url.textContent = text.slice(0, c + 1); return wait(45); }); }, wait(300))
        .then(function () { load.style.transform = 'scaleX(1)'; return wait(900); })
        .then(function () { load.className = 'bk-load done'; a.classList.add('loaded'); return wait(900); })
        .then(function () { a.classList.add('done'); return wait(3400); });
    }
    if (still) play(); else play(true).then(function loop() { return play().then(loop); });
  })(i);
});
