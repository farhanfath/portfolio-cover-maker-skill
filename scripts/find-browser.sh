#!/usr/bin/env bash
# Mencetak path binary browser Chromium-based ke stdout. Exit 1 kalau tidak ada.
set -u

for c in google-chrome-stable google-chrome chromium chromium-browser chrome msedge; do
  if command -v "$c" >/dev/null 2>&1; then command -v "$c"; exit 0; fi
done

CANDIDATES=(
  "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
  "/Applications/Chromium.app/Contents/MacOS/Chromium"
  "/Applications/Microsoft Edge.app/Contents/MacOS/Microsoft Edge"
  "/usr/bin/google-chrome"
  "/usr/bin/chromium"
  "/usr/bin/chromium-browser"
  "/opt/google/chrome/chrome"
  "/snap/bin/chromium"
  "/c/Program Files/Google/Chrome/Application/chrome.exe"
  "/c/Program Files (x86)/Google/Chrome/Application/chrome.exe"
  "/c/Program Files (x86)/Microsoft/Edge/Application/msedge.exe"
  "/c/Program Files/Microsoft/Edge/Application/msedge.exe"
)
for p in "${CANDIDATES[@]}"; do
  if [ -x "$p" ]; then printf '%s\n' "$p"; exit 0; fi
done
exit 1
