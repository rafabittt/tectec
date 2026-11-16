#!/bin/zsh
# Release do TecTec fora da App Store (mesmo fluxo do Legroom):
#   build universal → assinatura Developer ID (Hardened Runtime) → DMG → notarização → staple → appcast.
#
# Pré-requisitos (uma vez):
#   1. Certificado "Developer ID Application" no Keychain (Xcode › Settings › Accounts › Manage Certificates).
#   2. Credenciais de notarização no Keychain:
#        xcrun notarytool store-credentials <perfil> --apple-id SEU_APPLE_ID --team-id SEU_TEAM_ID --password SENHA_DE_APP
#      O perfil padrão é "legroom-notary" (o mesmo do Legroom); troque com NOTARY_PROFILE=<perfil>.
#   3. Chave de atualização do Sparkle no Keychain, conta "tectec" (generate_keys --account tectec).
#
# Para lançar uma versão nova:
#   1. Aumente VERSION e BUILD em version.env (BUILD sempre sobe: é o que o Sparkle compara).
#   2. Opcional: escreva as novidades em dist/notes-<versão>.html (vira o texto da janela de atualização).
#   3. tools/release.sh            → dist/TecTec-<versão>.dmg notarizado + appcast.xml atualizado
#   4. gh release create v<versão> dist/TecTec-<versão>.dmg, depois commit + push do appcast.xml
#      (ou tools/release.sh --publish, que faz o passo 4 sozinho).
set -euo pipefail
cd "$(dirname "$0")/.."

PROFILE=${NOTARY_PROFILE:-legroom-notary}
PUBLISH=0
[[ "${1:-}" == "--publish" ]] && PUBLISH=1

if ! security find-identity -v -p codesigning | grep -q "Developer ID Application"; then
  echo "✗ Nenhum certificado 'Developer ID Application' no Keychain." >&2
  exit 1
fi

source version.env
DIST=dist
DMG=$DIST/TecTec-$VERSION.dmg
mkdir -p "$DIST"
rm -f "$DMG"

echo "▸ build $VERSION ($BUILD) com Developer ID"
SIGN_ID="Developer ID Application" ./build.sh

echo "▸ DMG"
STAGE=$DIST/stage.noindex; rm -rf "$STAGE"; mkdir -p "$STAGE"
cp -R TecTec.app "$STAGE/"
ln -s /Applications "$STAGE/Applications"
hdiutil create -volname "TecTec" -srcfolder "$STAGE" -ov -format UDZO "$DMG" >/dev/null
rm -rf "$STAGE"
codesign --sign "Developer ID Application" --timestamp "$DMG"

echo "▸ notarização (pode levar alguns minutos)"
xcrun notarytool submit "$DMG" --keychain-profile "$PROFILE" --wait
echo "▸ staple"
xcrun stapler staple "$DMG"
xcrun stapler validate "$DMG"
echo "▸ Gatekeeper"
spctl --assess --type open --context context:primary-signature --verbose=2 "$DMG"

echo "▸ appcast (feed do Sparkle)"
NOTES=$DIST/notes-$VERSION.html
if [[ -f $NOTES ]]; then tools/appcast.py "$DMG" "$VERSION" "$BUILD" --notes "$NOTES"
else tools/appcast.py "$DMG" "$VERSION" "$BUILD"; fi

# O build local volta a ser ad-hoc, para não confundir a permissão de teclado durante o desenvolvimento.
./build.sh >/dev/null

echo "✓ $DMG"
if [[ $PUBLISH == 1 ]]; then
  echo "▸ GitHub Release v$VERSION"
  NOTES_ARGS=(--generate-notes)
  [[ -f $NOTES ]] && NOTES_ARGS=(--notes-file "$NOTES")
  gh release create "v$VERSION" "$DMG" --title "TecTec $VERSION" "${NOTES_ARGS[@]}"
  git add appcast.xml version.env
  git commit -m "Release $VERSION" >/dev/null
  git push
  echo "✓ publicado: quem tem o TecTec recebe o aviso de atualização"
else
  echo "  para publicar: gh release create v$VERSION $DMG, depois commit e push do appcast.xml"
fi
