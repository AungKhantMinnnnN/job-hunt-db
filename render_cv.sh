#!/bin/sh
# Render a CV's HTML source to PDF with headless Chrome: ./render_cv.sh cvs/foo.html -> cvs/foo.pdf
set -e
in=$(cd "$(dirname "$1")" && pwd)/$(basename "$1")
out=${in%.html}.pdf
"/Applications/Google Chrome.app/Contents/MacOS/Google Chrome" --headless --disable-gpu \
  --no-pdf-header-footer --print-to-pdf="$out" "file://$in" 2>/dev/null
[ -s "$out" ] && echo "$out"
