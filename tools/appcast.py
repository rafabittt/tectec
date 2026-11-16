#!/usr/bin/env python3
"""Adiciona uma versão ao appcast.xml (o feed de atualizações do Sparkle, na raiz do repo).

Uso:
    tools/appcast.py <dmg> <versão> <build> [--notes <arquivo.html>]

Assina o DMG com o `sign_update` do Sparkle (chave EdDSA no Keychain, conta "tectec")
e coloca um <item> novo no topo do feed. A URL de download é o DMG anexado ao
GitHub Release `v<versão>`: publique o release com o mesmo arquivo antes de dar push no appcast.
"""
import glob
import html
import os
import re
import subprocess
import sys
from email.utils import formatdate

REPO = "rafabittt/tectec"
ACCOUNT = "tectec"
MIN_SYSTEM = "13.0"
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
FEED = os.path.join(ROOT, "appcast.xml")

EMPTY = """<?xml version="1.0" encoding="utf-8"?>
<rss version="2.0" xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle">
  <channel>
    <title>TecTec</title>
    <link>https://github.com/{repo}</link>
    <description>Atualizações do TecTec</description>
    <language>pt-BR</language>
  </channel>
</rss>
"""


def find_sign_update():
    hits = sorted(glob.glob(os.path.join(ROOT, ".build/artifacts/sparkle/Sparkle/bin/sign_update")))
    if hits:
        return hits[-1]
    sys.exit("✗ sign_update não encontrado. Rode ./build.sh uma vez para o Swift Package Manager baixar o Sparkle.")


def main():
    args = sys.argv[1:]
    notes = None
    if "--notes" in args:
        i = args.index("--notes")
        notes = open(args[i + 1]).read()
        del args[i:i + 2]
    dmg, version, build = args
    out = subprocess.run([find_sign_update(), "--account", ACCOUNT, dmg],
                         check=True, capture_output=True, text=True).stdout.strip()
    sig = re.search(r'sparkle:edSignature="([^"]+)"', out).group(1)
    length = re.search(r'length="(\d+)"', out).group(1)
    url = f"https://github.com/{REPO}/releases/download/v{version}/{os.path.basename(dmg)}"
    release_page = f"https://github.com/{REPO}/releases/tag/v{version}"
    description = notes if notes else f'<p><a href="{release_page}">Novidades do TecTec {version}</a></p>'

    item = f"""    <item>
      <title>TecTec {html.escape(version)}</title>
      <pubDate>{formatdate(usegmt=True)}</pubDate>
      <sparkle:version>{html.escape(build)}</sparkle:version>
      <sparkle:shortVersionString>{html.escape(version)}</sparkle:shortVersionString>
      <sparkle:minimumSystemVersion>{MIN_SYSTEM}</sparkle:minimumSystemVersion>
      <sparkle:fullReleaseNotesLink>{release_page}</sparkle:fullReleaseNotesLink>
      <description><![CDATA[{description}]]></description>
      <enclosure url="{url}" length="{length}" type="application/octet-stream" sparkle:edSignature="{sig}"/>
    </item>
"""
    feed = open(FEED).read() if os.path.exists(FEED) else EMPTY.format(repo=REPO)
    # substitui uma entrada do mesmo build (rodar o release de novo)
    feed = re.sub(r"    <item>\n(?:(?!</item>).)*?<sparkle:version>" + re.escape(build) + r"</sparkle:version>.*?</item>\n",
                  "", feed, flags=re.S)
    feed = feed.replace("  </channel>", item + "  </channel>", 1) if "<item>" not in feed else \
        feed.replace("    <item>", item + "    <item>", 1)
    open(FEED, "w").write(feed)
    print(f"✓ appcast.xml: TecTec {version} ({build}) → {url}")


if __name__ == "__main__":
    main()
