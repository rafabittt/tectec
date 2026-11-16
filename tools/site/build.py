#!/usr/bin/env python3
"""Gera o site do TecTec em docs/ (servido pelo GitHub Pages).

    python3 tools/site/build.py

Escreve docs/index.html (português, a principal) e docs/en/index.html (inglês),
além de sitemap.xml e robots.txt. Estilos e efeitos ficam em docs/assets/site.css
e docs/assets/site.js; os sons do teste ficam em docs/sounds/. Sem dependências.
"""
import html
import json
import os

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
OUT = os.path.join(ROOT, "docs")
SITE = "https://rafabittt.github.io/tectec/"
REPO_SLUG = "rafabittt/tectec"
REPO = "https://github.com/" + REPO_SLUG
LATEST = REPO + "/releases/latest"
VERSION = open(os.path.join(ROOT, "version.env")).read().split("VERSION=")[1].split()[0]
SIZE = "1,9 MB"   # o JavaScript troca pelo tamanho real do último release

APPLE = '<svg viewBox="0 0 24 24" fill="currentColor" aria-hidden="true"><path d="M16.37 12.8c-.02-2.2 1.8-3.26 1.88-3.31-1.03-1.5-2.62-1.7-3.18-1.73-1.35-.14-2.64.8-3.33.8-.69 0-1.74-.78-2.87-.76-1.47.02-2.83.86-3.59 2.18-1.53 2.66-.39 6.6 1.1 8.76.73 1.06 1.6 2.24 2.73 2.2 1.1-.04 1.51-.71 2.84-.71 1.32 0 1.7.71 2.86.69 1.18-.02 1.93-1.07 2.65-2.14.84-1.23 1.18-2.42 1.2-2.48-.03-.01-2.3-.88-2.32-3.5zM14.2 6.33c.6-.73 1.01-1.75.9-2.76-.87.04-1.92.58-2.54 1.31-.56.64-1.05 1.67-.92 2.66.97.08 1.96-.49 2.56-1.21z"/></svg>'
GITHUB = '<svg viewBox="0 0 24 24" fill="currentColor" aria-hidden="true"><path d="M12 .5a11.5 11.5 0 0 0-3.64 22.41c.58.1.79-.25.79-.56v-2c-3.2.7-3.88-1.37-3.88-1.37-.52-1.33-1.28-1.69-1.28-1.69-1.05-.72.08-.7.08-.7 1.16.08 1.77 1.19 1.77 1.19 1.03 1.77 2.7 1.26 3.36.96.1-.75.4-1.26.73-1.55-2.55-.29-5.24-1.28-5.24-5.69 0-1.26.45-2.29 1.19-3.09-.12-.29-.52-1.46.11-3.05 0 0 .97-.31 3.17 1.18a11 11 0 0 1 5.77 0c2.2-1.49 3.17-1.18 3.17-1.18.63 1.59.23 2.76.11 3.05.74.8 1.19 1.83 1.19 3.09 0 4.42-2.69 5.39-5.26 5.68.41.36.78 1.06.78 2.14v3.17c0 .31.21.67.8.56A11.5 11.5 0 0 0 12 .5z"/></svg>'
STAR = '<svg viewBox="0 0 24 24" fill="currentColor" aria-hidden="true" style="width:14px;height:14px"><path d="M12 2.5l2.9 6.1 6.6.8-4.9 4.5 1.3 6.6L12 17.3 6.1 20.5l1.3-6.6L2.5 9.4l6.6-.8z"/></svg>'
CHECK = '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.4" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="M5 12.5l4.5 4.5L19 7.5"/></svg>'
PLAY = '<svg viewBox="0 0 24 24" fill="currentColor" aria-hidden="true" style="width:12px;height:12px"><path d="M7 4.5v15l13-7.5z"/></svg>'

def ico(path):
    return f'<span class="ico"><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.9" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">{path}</svg></span>'

I_MAP = ico('<rect x="2.5" y="6" width="19" height="12" rx="2.5"/><path d="M6 10h.01M9 10h.01M12 10h.01M15 10h.01M18 10h.01M8 14h8"/>')
I_BAR = ico('<rect x="3" y="4" width="18" height="16" rx="3"/><path d="M3 8.5h18M15 6.2h3"/>')
I_LOCK = ico('<rect x="5" y="10.5" width="14" height="10" rx="2.5"/><path d="M8 10.5V8a4 4 0 0 1 8 0v2.5"/>')
I_UP = ico('<path d="M12 16V4M7 9l5-5 5 5"/><path d="M4 15v3a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2v-3"/>')
I_WAVE = ico('<path d="M3 12h2l2-6 3 12 3-9 2 5 2-2h4"/>')
I_PACK = ico('<path d="M3 7.5 12 3l9 4.5-9 4.5z"/><path d="M3 7.5v9L12 21l9-4.5v-9M12 12v9"/>')

# Os mesmos 13 switches do app (Sources/TecTec/Switches.swift)
SWITCHES = [
    ("cream", "NovelKeys Cream", "linear", "POM autolubrificante, grave e levemente arranhado", "self-lubricating POM, deep and slightly scratchy"),
    ("blackink", "Gateron Black Ink", "linear", "pesado, carcaça fumê, thock profundo", "heavy, smoky housing, deep thock"),
    ("redink", "Gateron Red Ink", "linear", "leve, mais agudo e clacky", "light, brighter and clacky"),
    ("mxblack", "Cherry MX Black", "linear", "o linear clássico pesado, seco", "the classic heavy linear, dry"),
    ("alpaca", "Alpaca", "linear", "suave e cremoso, molas leves", "smooth and creamy, light springs"),
    ("turquoise", "Turquoise Tealios", "linear", "lubrificado de fábrica, limpo e poppy", "factory-lubed, clean and poppy"),
    ("holypanda", "Holy Panda", "tactile", "bump forte e arredondado, marcante", "strong rounded bump, punchy"),
    ("mxbrown", "Cherry MX Brown", "tactile", "bump suave, o tátil de escritório", "gentle bump, the office tactile"),
    ("mxblue", "Cherry MX Blue", "clicky", "clique agudo da jaqueta, o barulhento clássico", "sharp jacket click, the loud classic"),
    ("boxnavy", "Kailh Box Navy", "clicky", "clique de barra de mola, alto e pesado", "click-bar switch, loud and heavy"),
    ("bluealps", "SKCM Blue Alps", "clicky", "Alps vintage dos anos 80, clique cristalino", "vintage 1980s Alps, crystal-clear click"),
    ("buckling", "Buckling Spring", "special", "mola que flamba, o som do IBM Model M", "a buckling spring, the IBM Model M sound"),
    ("topre", "Topre", "special", "eletrocapacitivo de borracha, thock abafado", "electrocapacitive rubber dome, muted thock"),
]
DEFAULT = "holypanda"
TYPE_COLORS = {"linear": "#ff6b4a", "tactile": "#c08457", "clicky": "#4c8dff", "special": "#ffd43b"}

PT = dict(
    lang="pt-BR", path="", base="", other="en/", other_label="English", other_hreflang="en",
    title="TecTec: som de teclado mecânico no Mac, feito para o ABNT2",
    desc="O TecTec fica na barra de menus e toca um switch mecânico de verdade a cada tecla. 13 gravações reais, som espacial pelo layout ABNT2. Grátis e open source.",
    skip="Pular para o conteúdo",
    nav=[("#testar", "Testar"), ("#switches", "Switches"), ("#recursos", "Recursos"), ("#open-source", "Open source")],
    download="Baixar",
    eyebrow="Grátis e open source · macOS 13 ou mais recente",
    h1="Cada tecla, um <em>tec</em>.",
    lead="O TecTec fica na barra de menus e toca um switch mecânico de verdade a cada tecla que você aperta. 13 gravações reais e som espacial pelo layout ABNT2.",
    cta="Baixar para Mac", cta2="Ver no GitHub",
    meta='Versão <span data-version>{v}</span> · <span data-size>{s}</span> · Apple Silicon e Intel · Notarizado pela Apple',
    hint='Psiu: aperta qualquer tecla. Até o <kbd>Ç</kbd>.',
    types={"linear": "Lineares", "tactile": "Táteis", "clicky": "Clicky", "special": "Clássicos"},
    menu_on="Sons ativados", menu_upd="Procurar atualizações…", menu_quit="Sair",
    menu_alt="Menu do TecTec na barra de menus. Clique num switch para ouvir.",
    p_kicker="Testa aí", p_h="Digita. Ouve. Escolhe o seu.",
    p_p="Esse é o som de verdade do app. Aperta qualquer tecla, ou toca no teclado aqui embaixo, e troca de switch para comparar. Com fone, repara: o Q soa na esquerda, o Ç na direita.",
    board_label="Teclado ABNT2 interativo", textarea="Escreve alguma coisa aqui…", spatial="Som espacial", replay="Tocar prévia",
    now="Tocando:",
    s_kicker="Switches", s_h="13 switches. Cada um com a sua voz.",
    s_p="Gravações reais de cada switch, apertando e soltando, com um som para cada fileira do teclado. Clica para ouvir.",
    listen="Ouvir",
    f_kicker="Recursos", f_h="Pequeno por fora, caprichado por dentro.",
    f_p="Um app nativo, leve e discreto, que só faz uma coisa e faz bem feito.",
    f_photo=("Gravações reais, não síntese", "Cada switch foi gravado apertando e soltando, com som próprio para cada fileira, para o Espaço, o Enter e o Backspace."),
    f_photo_alt="Switch mecânico sem a tecla, com a haste vermelha em cruz e a mola aparente",
    f_abnt=("Feito para o ABNT2", "O som sai do lugar da tecla: Q na esquerda, Ç e ~ na direita. Com fone, fica imersivo."),
    f_bar=("Mora na barra de menus", "Nativo em Swift, leve e instantâneo. Sem janela e sem ícone no Dock."),
    f_priv=("Só escuta, não guarda", "Ouve as teclas para tocar o som e mais nada. Não grava, não envia, e campos de senha nem chegam até ele."),
    f_upd=("Atualiza sozinho", "Assinado e notarizado pela Apple. Quando sai versão nova, o TecTec avisa e instala."),
    f_var=("Nunca soa repetido", "Cada toque varia um pouco o tom, como num teclado de verdade. Dá para desligar o som ao soltar a tecla."),
    f_pack=("Seus próprios sons", "Importe pacotes do Mechvibes ou uma pasta de WAVs por tecla, e eles aparecem no menu."),
    i_kicker="Instalar", i_h="Três passos e pronto.",
    steps=[("Baixe e arraste", "Abra o DMG e arraste o TecTec para a pasta Aplicativos."),
           ("Dê a permissão", "Em Ajustes do Sistema › Privacidade e Segurança › <b>Monitoramento de Entrada</b>, ative o TecTec."),
           ("Escolha seu switch", "Clique no Ç da barra de menus e escolha. Pronto: tec, tec, tec.")],
    o_kicker="Open source", o_h="Código aberto, do jeito que tem que ser.",
    o_p="Todo o código está no GitHub. Dá para ler, compilar, mudar e mandar melhorias.",
    o_list=["Licença MIT, grátis para sempre", "Sem conta, sem telemetria, sem anúncio", "Sons do projeto kbsim e atualizações pelo Sparkle, ambos MIT",
            "Contribuições bem-vindas: novos switches, layouts e traduções"],
    o_code=["# compilar a partir do código", "git clone https://github.com/rafabittt/tectec", "cd tectec", "./build.sh && open TecTec.app"],
    fin_h="Bora fazer barulho?", fin_p="Grátis, open source e feito no Brasil.",
    fin_alt="",
    foot_links=[(REPO, "GitHub"), (REPO + "/releases", "Versões"), (REPO + "/issues", "Reportar um problema")],
    fine="Sons de switches: kbsim (MIT) © Thomas Lai. Os nomes dos switches são marcas dos seus donos e aparecem só para descrever o som. Sem relação com o Klack nem com os fabricantes. Imagens ilustrativas geradas com IA.",
    hero_alt="Teclado mecânico preto com uma tecla amarela em destaque",
    decimal=",",
)

EN = dict(
    lang="en", path="en/", base="../", other="../", other_label="Português", other_hreflang="pt-BR",
    title="TecTec: mechanical keyboard sounds for your Mac",
    desc="TecTec lives in the menu bar and plays a real mechanical switch on every key you press. 13 real recordings and spatial sound. Free and open source.",
    skip="Skip to content",
    nav=[("#testar", "Try it"), ("#switches", "Switches"), ("#recursos", "Features"), ("#open-source", "Open source")],
    download="Download",
    eyebrow="Free & open source · macOS 13 or later",
    h1="Every key, a satisfying <em>tec</em>.",
    lead="TecTec lives in your menu bar and plays a real mechanical switch on every key you press. 13 real recordings, with spatial sound that follows the key's position.",
    cta="Download for Mac", cta2="View on GitHub",
    meta='Version <span data-version>{v}</span> · <span data-size>{s}</span> · Apple silicon &amp; Intel · Notarized by Apple',
    hint="Psst: press any key.",
    types={"linear": "Linear", "tactile": "Tactile", "clicky": "Clicky", "special": "Classics"},
    menu_on="Sounds on", menu_upd="Check for Updates…", menu_quit="Quit",
    menu_alt="TecTec's menu bar menu. Click a switch to hear it.",
    p_kicker="Try it", p_h="Type. Listen. Pick yours.",
    p_p="This is the app's real sound. Press any key, or tap the keyboard below, and switch switches to compare. With headphones on, notice how Q sounds on the left and the right-hand keys on the right.",
    board_label="Interactive keyboard", textarea="Type something here…", spatial="Spatial sound", replay="Play preview",
    now="Now playing:",
    s_kicker="Switches", s_h="13 switches. Each with its own voice.",
    s_p="Real recordings of every switch, pressing and releasing, with a sound for each keyboard row. Click to listen.",
    listen="Listen",
    f_kicker="Features", f_h="Small on the outside, crafted on the inside.",
    f_p="A native, light, quiet app that does one thing and does it well.",
    f_photo=("Real recordings, not synthesis", "Every switch was recorded pressing and releasing, with its own sound for each row, Space, Enter and Backspace."),
    f_photo_alt="A mechanical switch without its keycap, red cross stem and spring visible",
    f_abnt=("Sound with a position", "The sound comes from where the key is: Q on the left, Enter on the right. Made for the Brazilian ABNT2 layout, too."),
    f_bar=("Lives in the menu bar", "Native Swift, light and instant. No window, no Dock icon."),
    f_priv=("Listens, never keeps", "It hears keys to play a sound and nothing else. Nothing is recorded or sent, and password fields never reach it."),
    f_upd=("Updates itself", "Signed and notarized by Apple. When a new version ships, TecTec tells you and installs it."),
    f_var=("Never sounds repetitive", "Every press varies the pitch a little, like a real keyboard. Release sounds can be turned off."),
    f_pack=("Bring your own sounds", "Import Mechvibes packs or a folder of per-key WAVs and they show up in the menu."),
    i_kicker="Install", i_h="Three steps and you're done.",
    steps=[("Download and drag", "Open the DMG and drag TecTec to Applications."),
           ("Grant permission", "In System Settings › Privacy &amp; Security › <b>Input Monitoring</b>, turn TecTec on."),
           ("Pick your switch", "Click the Ç in the menu bar and choose. That's it: tec, tec, tec.")],
    o_kicker="Open source", o_h="Open source, the way it should be.",
    o_p="All the code is on GitHub. Read it, build it, change it and send improvements.",
    o_list=["MIT licensed, free forever", "No account, no telemetry, no ads", "Sounds from the kbsim project and updates via Sparkle, both MIT",
            "Contributions welcome: new switches, layouts and translations"],
    o_code=["# build from source", "git clone https://github.com/rafabittt/tectec", "cd tectec", "./build.sh && open TecTec.app"],
    fin_h="Ready to make some noise?", fin_p="Free, open source and made in Brazil.",
    fin_alt="",
    foot_links=[(REPO, "GitHub"), (REPO + "/releases", "Releases"), (REPO + "/issues", "Report an issue")],
    fine="Switch sounds: kbsim (MIT) © Thomas Lai. Switch names are trademarks of their owners and appear only to describe the sound. Not affiliated with Klack or any manufacturer. Illustrative images generated with AI.",
    hero_alt="Black mechanical keyboard with one yellow key in focus",
    decimal=".",
)

e = html.escape


def page(L):
    b = L["base"]
    pt = L["lang"] == "pt-BR"
    url = SITE + L["path"]
    meta = L["meta"].format(v=VERSION, s=SIZE if pt else SIZE.replace(",", "."))
    switches = [{"id": i, "name": n, "type": t, "sound": (d_pt if pt else d_en)} for i, n, t, d_pt, d_en in SWITCHES]
    files = {}
    for i, *_ in SWITCHES:
        d = os.path.join(OUT, "sounds", i)
        files[i] = sorted(f"{sub}/{f[:-4]}" for sub in ("press", "release") for f in os.listdir(os.path.join(d, sub)) if f.endswith(".mp3"))
    data = {"repo": REPO_SLUG, "sounds": b + "sounds/", "defaultSwitch": DEFAULT, "decimal": L["decimal"], "files": files,
            "switches": switches, "t": {"now": L["now"]}}

    nav_links = "".join(f'<a href="{h}">{e(t)}</a>' for h, t in L["nav"])

    # menu de mentira (o app de verdade, em HTML)
    menu = []
    for t in ["linear", "tactile", "clicky", "special"]:
        menu.append(f'<div class="mh" role="presentation">{e(L["types"][t])}</div>')
        for s in switches:
            if s["type"] == t:
                menu.append(f'<button type="button" role="menuitemradio" aria-checked="false" data-switch="{s["id"]}">{e(s["name"])}</button>')
    menu_html = (f'<div class="menu-mock" role="menu" aria-label="{e(L["menu_alt"])}">'
                 f'<span class="anchor" aria-hidden="true"><img src="{b}assets/favicon.png" alt=""></span>'
                 + "".join(menu) +
                 f'<hr><button type="button" role="menuitem" data-preview>{e(L["replay"])}</button>'
                 f'<button type="button" role="menuitem" tabindex="-1" aria-disabled="true">{e(L["menu_upd"])}</button></div>')

    picker = []
    for t in ["linear", "tactile", "clicky", "special"]:
        chips = "".join(f'<button type="button" class="chip-btn" aria-pressed="false" data-switch="{s["id"]}">{e(s["name"])}</button>'
                        for s in switches if s["type"] == t)
        picker.append(f'<div class="grp" role="group" aria-label="{e(L["types"][t])}"><span>{e(L["types"][t])}</span>{chips}</div>')

    cards = "".join(
        f'<button type="button" class="sw reveal" aria-pressed="false" data-switch="{s["id"]}" style="--c:{TYPE_COLORS[s["type"]]}">'
        f'<span class="t"><i></i>{e(L["types"][s["type"]])}</span><h3>{e(s["name"])}</h3><p>{e(s["sound"])}</p>'
        f'<span class="play-i">{PLAY} {e(L["listen"])}</span></button>' for s in switches)

    def cell(cls, icon, ttl, body, extra=""):
        return f'<div class="cell {cls} reveal">{icon}<h3>{e(ttl)}</h3><p>{body}</p>{extra}</div>'

    spatial_viz = '<div class="spatial" aria-hidden="true"><b>Q</b><span></span><b>Ç</b></div>' if pt else '<div class="spatial" aria-hidden="true"><b>Q</b><span></span><b>⏎</b></div>'
    bento = (
        f'<div class="cell w4 photo reveal"><img src="{b}assets/switch.webp" alt="{e(L["f_photo_alt"])}" loading="lazy" width="1800" height="1012">'
        f'<div class="cap"><h3>{e(L["f_photo"][0])}</h3><p>{e(L["f_photo"][1])}</p></div></div>'
        + cell("", I_MAP, *L["f_abnt"], spatial_viz)
        + cell("", I_BAR, *L["f_bar"])
        + cell("", I_LOCK, *L["f_priv"])
        + cell("", I_UP, *L["f_upd"])
        + cell("w3", I_WAVE, *L["f_var"])
        + cell("w3", I_PACK, *L["f_pack"])
    )
    steps = "".join(f'<div class="step reveal"><h3>{e(t)}</h3><p>{d}</p></div>' for t, d in L["steps"])
    oss_list = "".join(f"<li>{CHECK}<span>{e(x)}</span></li>" for x in L["o_list"])
    code = "<br>".join(f'<span class="c">{e(l)}</span>' if l.startswith("#") else f'<span class="p">$</span> {e(l)}' for l in L["o_code"])
    foot = " · ".join(f'<a href="{h}">{e(t)}</a>' for h, t in L["foot_links"])

    return f"""<!doctype html>
<html lang="{L['lang']}">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover">
<title>{e(L['title'])}</title>
<meta name="description" content="{e(L['desc'])}">
<meta name="theme-color" content="#08080a">
<link rel="canonical" href="{url}">
<link rel="alternate" hreflang="pt-BR" href="{SITE}">
<link rel="alternate" hreflang="en" href="{SITE}en/">
<link rel="alternate" hreflang="x-default" href="{SITE}">
<meta property="og:type" content="website">
<meta property="og:title" content="{e(L['title'])}">
<meta property="og:description" content="{e(L['desc'])}">
<meta property="og:url" content="{url}">
<meta property="og:image" content="{SITE}assets/og.jpg">
<meta name="twitter:card" content="summary_large_image">
<link rel="icon" href="{b}assets/favicon.png">
<link rel="apple-touch-icon" href="{b}assets/icon-180.png">
<link rel="preload" as="image" href="{b}assets/hero.webp">
<link rel="stylesheet" href="{b}assets/site.css">
<script type="application/ld+json">{json.dumps({"@context": "https://schema.org", "@type": "SoftwareApplication", "name": "TecTec", "operatingSystem": "macOS 13+", "applicationCategory": "UtilitiesApplication", "offers": {"@type": "Offer", "price": "0", "priceCurrency": "USD"}, "downloadUrl": LATEST, "softwareVersion": VERSION, "license": "https://opensource.org/licenses/MIT", "url": url}, ensure_ascii=False)}</script>
</head>
<body>
<a class="skip" href="#main">{e(L['skip'])}</a>
<nav class="nav" aria-label="TecTec">
  <a class="brand" href="{b if b else './'}"><img src="{b}assets/icon-180.png" alt="" width="28" height="28">TecTec</a>
  <div class="links">{nav_links}</div>
  <a class="lang" href="{L['other']}" hreflang="{L['other_hreflang']}" lang="{L['other_hreflang']}">{L['other_label']}</a>
  <a class="btn btn-ghost btn-sm stars" href="{REPO}" hidden>{STAR}<span data-stars></span></a>
  <a class="btn btn-primary btn-sm" href="{LATEST}" data-download>{e(L['download'])}</a>
</nav>

<main id="main">
<header class="hero">
  <div class="hero-bg"><img src="{b}assets/hero.webp" alt="{e(L['hero_alt'])}" width="1800" height="1012" fetchpriority="high"></div>
  <div class="wrap">
    <div class="hero-in">
      <span class="eyebrow"><span class="dot" aria-hidden="true"></span>{e(L['eyebrow'])}</span>
      <h1>{L['h1']}</h1>
      <p class="lead">{e(L['lead'])}</p>
      <div class="ctas">
        <a class="btn btn-primary" href="{LATEST}" data-download>{APPLE}{e(L['cta'])}</a>
        <a class="btn btn-ghost" href="{REPO}">{GITHUB}{e(L['cta2'])}</a>
      </div>
      <p class="meta">{meta}</p>
      <p class="hint">{L['hint']}</p>
    </div>
  </div>
  {menu_html}
</header>

<section class="play" id="testar">
  <div class="wrap">
    <div class="head center reveal">
      <span class="kicker">{e(L['p_kicker'])}</span>
      <h2>{e(L['p_h'])}</h2>
      <p>{e(L['p_p'])}</p>
    </div>
    <div class="picker">{''.join(picker)}</div>
    <div class="board" id="board" role="group" aria-label="{e(L['board_label'])}"></div>
    <p class="now" id="now" aria-live="polite"></p>
    <div class="play-tools">
      <textarea rows="1" placeholder="{e(L['textarea'])}" aria-label="{e(L['textarea'])}"></textarea>
      <label class="toggle"><input type="checkbox" id="spatial" checked> {e(L['spatial'])}</label>
      <button type="button" class="btn btn-ghost btn-sm" data-preview>{PLAY} {e(L['replay'])}</button>
    </div>
  </div>
</section>

<section class="sw-band" id="switches">
  <div class="bg" aria-hidden="true"><img src="{b}assets/keycaps.webp" alt="" loading="lazy"></div>
  <div class="wrap">
    <div class="head reveal">
      <span class="kicker">{e(L['s_kicker'])}</span>
      <h2>{e(L['s_h'])}</h2>
      <p>{e(L['s_p'])}</p>
    </div>
    <div class="sw-grid">{cards}</div>
  </div>
</section>

<section id="recursos">
  <div class="wrap">
    <div class="head reveal">
      <span class="kicker">{e(L['f_kicker'])}</span>
      <h2>{e(L['f_h'])}</h2>
      <p>{e(L['f_p'])}</p>
    </div>
    <div class="bento">{bento}</div>
  </div>
</section>

<section id="instalar">
  <div class="wrap">
    <div class="head reveal">
      <span class="kicker">{e(L['i_kicker'])}</span>
      <h2>{e(L['i_h'])}</h2>
    </div>
    <div class="steps">{steps}</div>
  </div>
</section>

<section id="open-source">
  <div class="wrap oss">
    <div class="reveal">
      <span class="kicker">{e(L['o_kicker'])}</span>
      <h2 style="font-size:clamp(34px,4.6vw,54px);line-height:1.04;margin:12px 0 14px">{e(L['o_h'])}</h2>
      <p style="color:var(--dim);font-size:18px">{e(L['o_p'])}</p>
      <ul>{oss_list}</ul>
      <a class="btn btn-ghost" href="{REPO}">{GITHUB}{e(L['cta2'])}</a>
    </div>
    <div class="code-card reveal" aria-label="Terminal">{code}</div>
  </div>
</section>

<section class="final">
  <div class="bg" aria-hidden="true"><img src="{b}assets/cta.webp" alt="" loading="lazy"></div>
  <div class="wrap">
    <img class="icon" src="{b}assets/icon-512.png" alt="" width="104" height="104">
    <h2>{e(L['fin_h'])}</h2>
    <p>{e(L['fin_p'])}</p>
    <div class="ctas">
      <a class="btn btn-primary" href="{LATEST}" data-download>{APPLE}{e(L['cta'])}</a>
      <a class="btn btn-ghost" href="{REPO}">{GITHUB}GitHub</a>
    </div>
    <p class="meta">{meta}</p>
  </div>
</section>
</main>

<footer>
  <div class="wrap">
    <span>© 2026 TecTec · MIT · {foot}</span>
    <span class="fine">{e(L['fine'])}</span>
  </div>
</footer>
<script type="application/json" id="data">{json.dumps(data, ensure_ascii=False)}</script>
<script src="{b}assets/site.js" defer></script>
</body>
</html>
"""


def main():
    os.makedirs(os.path.join(OUT, "en"), exist_ok=True)
    for L in (PT, EN):
        with open(os.path.join(OUT, L["path"], "index.html"), "w") as f:
            f.write(page(L))
    with open(os.path.join(OUT, "sitemap.xml"), "w") as f:
        f.write(f'<?xml version="1.0" encoding="UTF-8"?>\n<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">\n'
                f'  <url><loc>{SITE}</loc></url>\n  <url><loc>{SITE}en/</loc></url>\n</urlset>\n')
    with open(os.path.join(OUT, "robots.txt"), "w") as f:
        f.write(f"User-agent: *\nAllow: /\nSitemap: {SITE}sitemap.xml\n")
    open(os.path.join(OUT, ".nojekyll"), "w").close()
    print("✓ docs/index.html, docs/en/index.html")


if __name__ == "__main__":
    main()
