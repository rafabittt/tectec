// Site do TecTec. Sem dependências. Sem JavaScript vira uma página estática;
// com prefers-reduced-motion as animações somem, mas o som continua.
(() => {
  const D = JSON.parse(document.getElementById("data").textContent);
  const $ = (s, r = document) => r.querySelector(s);
  const $$ = (s, r = document) => [...r.querySelectorAll(s)];

  // ---------- teclado ABNT2: [code, rótulo, largura, especial] ----------
  const ROWS = [
    [["Escape", "esc", 1.5], ["F1", "F1"], ["F2", "F2"], ["F3", "F3"], ["F4", "F4"], ["F5", "F5"], ["F6", "F6"], ["F7", "F7"], ["F8", "F8"], ["F9", "F9"], ["F10", "F10"], ["F11", "F11"], ["F12", "F12"], ["Power", "", 1.5, "gap"]],
    [["Backquote", "'"], ["Digit1", "1"], ["Digit2", "2"], ["Digit3", "3"], ["Digit4", "4"], ["Digit5", "5"], ["Digit6", "6"], ["Digit7", "7"], ["Digit8", "8"], ["Digit9", "9"], ["Digit0", "0"], ["Minus", "-"], ["Equal", "="], ["Backspace", "⌫", 2]],
    [["Tab", "⇥", 1.5], ["KeyQ", "Q"], ["KeyW", "W"], ["KeyE", "E"], ["KeyR", "R"], ["KeyT", "T"], ["KeyY", "Y"], ["KeyU", "U"], ["KeyI", "I"], ["KeyO", "O"], ["KeyP", "P"], ["BracketLeft", "´"], ["BracketRight", "["], ["Enter", "⏎", 1.5]],
    [["CapsLock", "⇪", 1.75], ["KeyA", "A"], ["KeyS", "S"], ["KeyD", "D"], ["KeyF", "F"], ["KeyG", "G"], ["KeyH", "H"], ["KeyJ", "J"], ["KeyK", "K"], ["KeyL", "L"], ["Semicolon", "Ç", 1, "br"], ["Quote", "~"], ["Backslash", "]"], ["EnterB", "", 1.25]],
    [["ShiftLeft", "⇧", 1.25], ["IntlBackslash", "\\"], ["KeyZ", "Z"], ["KeyX", "X"], ["KeyC", "C"], ["KeyV", "V"], ["KeyB", "B"], ["KeyN", "N"], ["KeyM", "M"], ["Comma", ","], ["Period", "."], ["Slash", ";"], ["IntlRo", "/"], ["ShiftRight", "⇧", 1.75]],
    [["Fn", "fn"], ["ControlLeft", "⌃"], ["AltLeft", "⌥"], ["MetaLeft", "⌘", 1.25], ["Space", "", 5.5], ["MetaRight", "⌘", 1.25], ["AltRight", "⌥"], ["ArrowLeft", "←"], ["ArrowDown", "↓"], ["ArrowRight", "→"]],
  ];
  const POS = {};   // code -> { x: -1..1, row }
  const TOTAL = 15;
  ROWS.forEach((row, r) => {
    let x = 0;
    row.forEach(([code, , w = 1]) => { POS[code] = { x: ((x + w / 2) / TOTAL) * 2 - 1, row: r }; x += w; });
  });
  POS.ArrowUp = { x: POS.ArrowDown.x, row: 5 };
  POS.NumpadEnter = POS.Enter;

  const board = $("#board");
  if (board) {
    ROWS.forEach((row, r) => {
      const el = document.createElement("div");
      el.className = "row" + (r === 0 ? " fn" : "");
      row.forEach(([code, label, w = 1, kind]) => {
        const k = document.createElement("button");
        k.type = "button";
        k.className = "key" + (r === 0 ? " fnk" : "") + (kind ? " " + kind : "");
        k.style.setProperty("--w", w);
        k.dataset.code = code === "EnterB" ? "Enter" : code;
        k.textContent = label;
        if (kind === "gap") { k.tabIndex = -1; k.setAttribute("aria-hidden", "true"); }
        else k.setAttribute("aria-label", label || code);
        el.appendChild(k);
      });
      board.appendChild(el);
    });
  }

  // ---------- áudio ----------
  let ctx = null, master = null;
  const cache = new Map();
  let current = D.defaultSwitch;
  let spatial = true;
  const PRESS = ["GENERIC_R0", "GENERIC_R1", "GENERIC_R2", "GENERIC_R3", "GENERIC_R4", "SPACE", "ENTER", "BACKSPACE"];
  const RELEASE = ["GENERIC", "SPACE", "ENTER", "BACKSPACE"];

  function audio() {
    if (!ctx) {
      ctx = new (window.AudioContext || window.webkitAudioContext)();
      master = ctx.createGain(); master.gain.value = .8; master.connect(ctx.destination);
    }
    if (ctx.state === "suspended") ctx.resume();
    return ctx;
  }
  async function buf(id, dir, name) {
    const key = `${id}/${dir}/${name}`;
    if (D.files && D.files[id] && !D.files[id].includes(`${dir}/${name}`)) return null;   // gravação que não existe (ex.: Espaço do MX Blue)
    if (!cache.has(key)) {
      cache.set(key, fetch(`${D.sounds}${key}.mp3`)
        .then(r => r.ok ? r.arrayBuffer() : Promise.reject())
        .then(a => new Promise((ok, no) => audio().decodeAudioData(a, ok, no)))
        .catch(() => null));
    }
    return cache.get(key);
  }
  function preload(id) {
    PRESS.forEach(n => buf(id, "press", n));
    RELEASE.forEach(n => buf(id, "release", n));
  }
  function names(code, down) {
    const big = { Space: "SPACE", Enter: "ENTER", NumpadEnter: "ENTER", Backspace: "BACKSPACE" }[code];
    if (down) return big ? [big, "GENERIC_R4"] : ["GENERIC_R" + Math.min(POS[code]?.row ?? 3, 4)];
    return big ? [big, "GENERIC"] : ["GENERIC"];
  }
  async function play(code, down) {
    const c = audio();
    let b = null;
    for (const n of names(code, down)) { b = await buf(current, down ? "press" : "release", n); if (b) break; }
    if (!b) return;
    const src = c.createBufferSource();
    src.buffer = b;
    src.playbackRate.value = 0.97 + Math.random() * 0.06;
    let node = src;
    if (c.createStereoPanner) {
      const p = c.createStereoPanner();
      p.pan.value = spatial ? (POS[code]?.x ?? 0) * .85 : 0;
      src.connect(p); node = p;
    }
    node.connect(master);
    src.start();
  }

  // ---------- teclas ----------
  const em = $(".hero h1 em");
  const held = new Set();
  function visual(code, down) {
    $$(`.key[data-code="${code}"]`).forEach(k => {
      k.classList.toggle("down", down);
      if (down) { k.classList.remove("glow"); void k.offsetWidth; k.classList.add("glow"); }
    });
    if (down && em) { em.classList.remove("hit"); void em.offsetWidth; em.classList.add("hit"); }
  }
  function press(code) { if (held.has(code)) return; held.add(code); visual(code, true); play(code, true); }
  function release(code) { if (!held.has(code)) return; held.delete(code); visual(code, false); play(code, false); }

  const playSec = $("#testar");
  let playVisible = false;
  if (playSec && "IntersectionObserver" in window) {
    new IntersectionObserver(([e]) => { playVisible = e.isIntersecting; }, { threshold: .25 }).observe(playSec);
  }
  addEventListener("keydown", e => {
    if (e.repeat) return;
    const code = e.code || "";
    if (!code || code === "Unidentified") return;
    const typing = e.target.closest && e.target.closest("input, textarea, [contenteditable]");
    if (!typing && playVisible && (code === "Space" || code.startsWith("Arrow"))) e.preventDefault();
    press(code);
  });
  addEventListener("keyup", e => release(e.code || ""));
  addEventListener("blur", () => [...held].forEach(release));

  if (board) {
    board.addEventListener("pointerdown", e => {
      const k = e.target.closest(".key"); if (!k || k.classList.contains("gap")) return;
      e.preventDefault(); k.setPointerCapture?.(e.pointerId); press(k.dataset.code);
      const up = () => { release(k.dataset.code); k.removeEventListener("pointerup", up); k.removeEventListener("pointercancel", up); };
      k.addEventListener("pointerup", up); k.addEventListener("pointercancel", up);
    });
    board.addEventListener("keydown", e => { if (e.key === "Enter" || e.key === " ") e.stopPropagation(); });
  }

  // ---------- escolha de switch (seletor, cartões e menu de mentira ficam em sincronia) ----------
  const nowEl = $("#now");
  function select(id, demo) {
    current = id;
    const sw = D.switches.find(s => s.id === id);
    $$("[data-switch]").forEach(b => {
      const on = b.dataset.switch === id;
      b.setAttribute(b.getAttribute("role") === "menuitemradio" ? "aria-checked" : "aria-pressed", String(on));
    });
    if (nowEl && sw) nowEl.innerHTML = `${D.t.now} <b>${sw.name}</b> · ${sw.sound}`;
    preload(id);
    if (demo) preview();
  }
  let demoTimers = [];
  function preview() {
    demoTimers.forEach(clearTimeout); demoTimers = [];
    const seq = ["KeyT", "KeyE", "KeyC", "KeyT", "KeyE", "KeyC", "Space", "KeyB", "KeyR", "KeyA", "KeyS", "KeyI", "KeyL", "Enter"];
    let t = 120;
    seq.forEach(code => {
      demoTimers.push(setTimeout(() => press(code), t));
      demoTimers.push(setTimeout(() => release(code), t + 80));
      t += code === "Space" ? 300 : 150;
    });
  }
  $$("[data-switch]").forEach(b => b.addEventListener("click", () => { audio(); select(b.dataset.switch, true); }));
  $$("[data-preview]").forEach(b => b.addEventListener("click", () => { audio(); preview(); }));
  const sp = $("#spatial");
  if (sp) sp.addEventListener("change", () => { spatial = sp.checked; });
  select(current, false);

  // ---------- reveal, nav ----------
  const nav = $(".nav");
  const onScroll = () => nav && nav.classList.toggle("scrolled", scrollY > 30);
  addEventListener("scroll", onScroll, { passive: true }); onScroll();
  if ("IntersectionObserver" in window) {
    const io = new IntersectionObserver(es => es.forEach(e => { if (e.isIntersecting) { e.target.classList.add("in"); io.unobserve(e.target); } }), { rootMargin: "0px 0px -8% 0px" });
    $$(".reveal").forEach(el => io.observe(el));
  } else $$(".reveal").forEach(el => el.classList.add("in"));

  // ---------- versão e estrelas ao vivo do GitHub ----------
  fetch(`https://api.github.com/repos/${D.repo}/releases/latest`).then(r => r.ok ? r.json() : null).then(rel => {
    if (!rel) return;
    const v = (rel.tag_name || "").replace(/^v/, "");
    const dmg = (rel.assets || []).find(a => a.name.endsWith(".dmg"));
    if (v) $$("[data-version]").forEach(el => el.textContent = v);
    if (dmg) {
      $$("[data-size]").forEach(el => el.textContent = (dmg.size / 1048576).toFixed(1).replace(".", D.decimal) + " MB");
      $$("[data-download]").forEach(a => a.href = dmg.browser_download_url);
    }
  }).catch(() => {});
  fetch(`https://api.github.com/repos/${D.repo}`).then(r => r.ok ? r.json() : null).then(repo => {
    if (!repo) return;
    $$(".stars").forEach(el => { el.querySelector("[data-stars]").textContent = repo.stargazers_count; el.hidden = false; });
  }).catch(() => {});
})();
