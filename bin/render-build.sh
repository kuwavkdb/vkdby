#!/usr/bin/env bash
# exit on error
set -o errexit

bundle install
bundle exec rails tailwindcss:build
bundle exec rails assets:precompile
bundle exec rails assets:clean

# Download a CJK-capable font for OgpImageGenerator (issue #1268). Production (www.vkdb.jp)
# runs on Render's native Ruby runtime via this script, not the Dockerfile (Dockerfile/Kamal
# is unused), so there's no OS package manager to install fonts-noto-cjk from like the
# Dockerfile does. Fetch the font file directly instead. Not committed to the repo (see
# OgpImageGenerator's "don't bundle font files" policy; vendor/fonts is gitignored) and
# best-effort: if this fails (e.g. transient network error), don't fail the whole deploy —
# OgpImageGenerator.cjk_font_file just returns nil and falls back to the generic 'Sans Bold'
# font name.
mkdir -p vendor/fonts
curl -fsSL -o vendor/fonts/NotoSansCJKjp-Bold.otf \
  https://raw.githubusercontent.com/notofonts/noto-cjk/main/Sans/OTF/Japanese/NotoSansCJKjp-Bold.otf \
  || echo 'WARNING: failed to download the CJK font; OGP banner text will render without Japanese glyphs'
