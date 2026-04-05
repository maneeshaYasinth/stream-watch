#!/bin/bash
set -e

echo "[package] Cleaning old build..."
rm -rf build lambda.zip

echo "[package] Installing dependencies..."
mkdir -p build
python3.12 -m pip install -r function/requirements.txt -t build/ --quiet

echo "[package] Adding function code..."
cp function/lambda_function.py build/

echo "[package] Zipping..."
cd build
zip -r ../lambda.zip . --quiet
cd ..

echo "[package] Done → lambda.zip"
