#!/usr/bin/env bash
# Multi-OS build for mf-cli-appsec
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
mkdir -p bin

echo "Fetching modules..."
go mod tidy

echo "Building host binary..."
go build -o bin/mf-cli-appsec ./cmd/mf-cli-appsec

echo "Cross-compiling..."
GOOS=windows GOARCH=amd64 go build -o bin/mf-cli-appsec-windows-amd64.exe ./cmd/mf-cli-appsec
GOOS=linux   GOARCH=amd64 go build -o bin/mf-cli-appsec-linux-amd64 ./cmd/mf-cli-appsec
GOOS=linux   GOARCH=arm64 go build -o bin/mf-cli-appsec-linux-arm64 ./cmd/mf-cli-appsec
GOOS=darwin  GOARCH=amd64 go build -o bin/mf-cli-appsec-darwin-amd64 ./cmd/mf-cli-appsec
GOOS=darwin  GOARCH=arm64 go build -o bin/mf-cli-appsec-darwin-arm64 ./cmd/mf-cli-appsec

echo "Done. Binaries in bin/"
ls -la bin/
