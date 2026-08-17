/* ==========================================================================
   The identifying animation for geofleetic.com — SHELL.md §8.

   What it depicts: spatial relations resolving. Assets sit on a survey grid;
   a boundary assembles itself vertex by vertex around some of them; when it
   closes, the assets inside it answer "contained" and light up; a route
   threads between two of them and a marker walks it. Those three relations —
   contains, enter_exit, route — are the whole subject of the specification
   this page is about, and NOTHING HERE IS RUNNING. It is the specification
   drawing itself, which is the truthful picture for a spec-rung surface.

   IT RENDERS NO DATA AND ASSERTS NOTHING. §8.1 rule 2 is not negotiable and
   it is written in blood: gpscoord.com published `for (let i = 0; i < 12; i++)`
   — the loop bound of a decorative animation — beside the words "Active
   Pathfinders", for months.

   So this file takes NO input from the document and writes NOTHING back into
   it. It queries exactly one element, its own canvas, and touches nothing
   else. Its counts are deliberately unrelated to anything on the page. If a
   number here ever collides with a number in the page's text, launch-gate.mjs
   refuses the build — and the fix is to change THIS FILE, never the page.
   Decoration yields.
   ========================================================================== */
(function () {
  var host = document.querySelector("[data-identity-animation]");
  if (!host || !host.getContext) return;
  var ctx = host.getContext("2d");
  if (!ctx) return;

  var FPS = 24;
  var FRAME = 1000 / FPS;
  var reduce = window.matchMedia && window.matchMedia("(prefers-reduced-motion: reduce)");

  /* palette, read from nothing; these are literals on purpose */
  var ACC = "107,140,255";
  var DIM = "231,236,245";
  var SIG = "90,209,200";

  /* a seeded generator, so the picture is the same on every load */
  var seed = 0x2c91f5;
  function rnd() {
    seed ^= seed << 13; seed >>>= 0;
    seed ^= seed >> 17;
    seed ^= seed << 5;  seed >>>= 0;
    return (seed >>> 8) / 16777216;
  }

  var ASSETS = 27;
  var assets = [];
  var w = 0, h = 0, tick = 0, last = 0, raf = 0;

  function layout(ww, hh) {
    assets.length = 0;
    var padx = ww * 0.09, pady = hh * 0.11;
    for (var i = 0; i < ASSETS; i++) {
      assets.push({
        x: padx + rnd() * (ww - padx * 2),
        y: pady + rnd() * (hh - pady * 2),
        lit: 0,
        r: 1.5 + rnd() * 1.7
      });
    }
  }

  /* --- boundaries: a polygon that assembles, holds, then dissolves -------- */
  var FENCES = 3;
  var fences = [];
  function sprout() {
    if (!assets.length) return;
    var c = assets[Math.floor(rnd() * assets.length)];
    var n = 5 + Math.floor(rnd() * 3);
    var rad = Math.min(w, h) * (0.17 + rnd() * 0.14);
    var turn = rnd() * 6.28;
    var pts = [];
    for (var i = 0; i < n; i++) {
      var a = turn + (i / n) * 6.28;
      var k = rad * (0.72 + rnd() * 0.5);
      pts.push({ x: c.x + Math.cos(a) * k, y: c.y + Math.sin(a) * k * 0.82 });
    }
    fences.push({ pts: pts, t: 0, life: 250 + rnd() * 120, done: 0 });
  }

  function inside(p, pts) {
    var yes = false;
    for (var i = 0, j = pts.length - 1; i < pts.length; j = i++) {
      if ((pts[i].y > p.y) !== (pts[j].y > p.y) &&
          p.x < (pts[j].x - pts[i].x) * (p.y - pts[i].y) / (pts[j].y - pts[i].y) + pts[i].x) {
        yes = !yes;
      }
    }
    return yes;
  }

  /* --- one route, threading between two assets --------------------------- */
  var route = null;
  function thread() {
    if (assets.length < 4) return;
    var a = assets[Math.floor(rnd() * assets.length)];
    var z = assets[Math.floor(rnd() * assets.length)];
    if (a === z) return;
    var legs = [a];
    var steps = 2 + Math.floor(rnd() * 2);
    for (var i = 1; i <= steps; i++) {
      var f = i / (steps + 1);
      legs.push({
        x: a.x + (z.x - a.x) * f + (rnd() - 0.5) * w * 0.18,
        y: a.y + (z.y - a.y) * f + (rnd() - 0.5) * h * 0.2
      });
    }
    legs.push(z);
    route = { legs: legs, t: 0, life: 210 };
  }

  /* --- drawing ----------------------------------------------------------- */
  function grid() {
    var step = Math.max(24, Math.min(w, h) / 7);
    ctx.fillStyle = "rgba(" + DIM + ",.055)";
    for (var x = step * 0.5; x < w; x += step) {
      for (var y = step * 0.5; y < h; y += step) {
        ctx.fillRect(x, y, 1, 1);
      }
    }
  }

  function draw() {
    ctx.clearRect(0, 0, w, h);
    grid();

    /* boundaries first, so assets sit on top of them */
    for (var e = fences.length - 1; e >= 0; e--) {
      var g = fences[e];
      g.t += 1;
      if (g.t > g.life) { fences.splice(e, 1); continue; }
      var p = g.t / g.life;
      var grow = p < 0.32 ? p / 0.32 : 1;
      var fade = p > 0.8 ? 1 - (p - 0.8) / 0.2 : 1;
      var pts = g.pts;
      var span = grow * pts.length;
      ctx.beginPath();
      ctx.moveTo(pts[0].x, pts[0].y);
      for (var i = 1; i <= Math.floor(span); i++) {
        var q = pts[i % pts.length];
        ctx.lineTo(q.x, q.y);
      }
      var frac = span - Math.floor(span);
      if (frac > 0 && Math.floor(span) < pts.length) {
        var f0 = pts[Math.floor(span) % pts.length];
        var f1 = pts[(Math.floor(span) + 1) % pts.length];
        ctx.lineTo(f0.x + (f1.x - f0.x) * frac, f0.y + (f1.y - f0.y) * frac);
      }
      ctx.strokeStyle = "rgba(" + ACC + "," + 0.5 * fade + ")";
      ctx.lineWidth = 1.2;
      ctx.stroke();

      if (grow >= 1) {
        if (!g.done) {
          g.done = 1;
          for (var k = 0; k < assets.length; k++) {
            if (inside(assets[k], pts)) assets[k].lit = 1;
          }
        }
        ctx.fillStyle = "rgba(" + ACC + "," + 0.055 * fade + ")";
        ctx.fill();
      }
    }

    /* the route */
    if (route) {
      route.t += 1;
      if (route.t > route.life) { route = null; }
    }
    if (route) {
      var rp = route.t / route.life;
      var rg = rp < 0.4 ? rp / 0.4 : 1;
      var rf = rp > 0.76 ? 1 - (rp - 0.76) / 0.24 : 1;
      var L = route.legs;
      var upto = rg * (L.length - 1);
      ctx.beginPath();
      ctx.moveTo(L[0].x, L[0].y);
      for (var m = 1; m <= Math.ceil(upto); m++) {
        var prev = L[m - 1], next = L[m];
        var t2 = Math.min(1, upto - (m - 1));
        ctx.lineTo(prev.x + (next.x - prev.x) * t2, prev.y + (next.y - prev.y) * t2);
      }
      ctx.strokeStyle = "rgba(" + SIG + "," + 0.6 * rf + ")";
      ctx.lineWidth = 1.5;
      ctx.stroke();
      var mi = Math.min(L.length - 1, Math.max(1, Math.ceil(upto)));
      var pa = L[mi - 1], pz = L[mi], tt = Math.min(1, upto - (mi - 1));
      ctx.beginPath();
      ctx.arc(pa.x + (pz.x - pa.x) * tt, pa.y + (pz.y - pa.y) * tt, 2.6, 0, Math.PI * 2);
      ctx.fillStyle = "rgba(" + SIG + "," + 0.9 * rf + ")";
      ctx.fill();
    }

    /* the assets */
    for (var n = 0; n < assets.length; n++) {
      var s = assets[n];
      s.lit *= 0.972;
      ctx.beginPath();
      ctx.arc(s.x, s.y, s.r + s.lit * 1.7, 0, Math.PI * 2);
      ctx.fillStyle = "rgba(" + DIM + "," + (0.2 + s.lit * 0.6) + ")";
      ctx.fill();
      if (s.lit > 0.05) {
        ctx.beginPath();
        ctx.arc(s.x, s.y, s.r + 4.5 + (1 - s.lit) * 6, 0, Math.PI * 2);
        ctx.strokeStyle = "rgba(" + ACC + "," + s.lit * 0.5 + ")";
        ctx.lineWidth = 1;
        ctx.stroke();
      }
    }
  }

  /* --- the loop ---------------------------------------------------------- */
  function size() {
    var r = host.getBoundingClientRect();
    var dpr = Math.min(window.devicePixelRatio || 1, 1.75);
    w = Math.max(r.width, 160); h = Math.max(r.height, 160);
    host.width = Math.round(w * dpr);
    host.height = Math.round(h * dpr);
    ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
    seed = 0x2c91f5;
    layout(w, h);
    fences.length = 0;
    route = null;
  }

  function still() {
    size();
    sprout(); sprout();
    for (var i = 0; i < 90; i++) draw();
  }

  function frame(now) {
    raf = window.requestAnimationFrame(frame);
    /* Stop when the tab is hidden, and when the hero has scrolled away.
       IntersectionObserver is NOT used at all — it never fires in a
       non-compositing renderer, and an animation that never starts reads as
       a broken page. SHELL.md §6. */
    if (document.hidden) return;
    if (now - last < FRAME) return;
    last = now;
    var r = host.getBoundingClientRect();
    if (r.bottom < 0 || r.top > window.innerHeight) return;
    tick++;
    if (fences.length < FENCES && tick % 61 === 0) sprout();
    if (!route && tick % 97 === 0) thread();
    draw();
  }

  function boot() {
    if (reduce && reduce.matches) { still(); return; }
    size();
    sprout();
    thread();
    if (raf) window.cancelAnimationFrame(raf);
    raf = window.requestAnimationFrame(frame);
  }

  var t = 0;
  window.addEventListener("resize", function () {
    window.clearTimeout(t);
    t = window.setTimeout(boot, 170);
  });
  if (reduce) reduce.onchange = boot;
  boot();
})();
