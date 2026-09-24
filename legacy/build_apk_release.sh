#!/bin/bash
set -euo pipefail

APP_DIR="D:/work/z_ai_img"

echo "[1/3] flutter clean"
cd "$APP_DIR"
"D:/flutter/bin/flutter" clean

echo "[2/3] flutter pub get"
"D:/flutter/bin/flutter" pub get

echo "[3/3] flutter build apk --release"
"D:/flutter/bin/flutter" build apk --release
