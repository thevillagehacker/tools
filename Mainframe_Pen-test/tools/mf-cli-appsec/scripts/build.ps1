# Multi-OS build for mf-cli-appsec (Windows PowerShell)
$ErrorActionPreference = "Stop"
$Root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
Set-Location $Root
New-Item -ItemType Directory -Force -Path bin | Out-Null

Write-Host "Fetching modules..."
go mod tidy

$Go = "go"
if (Test-Path "C:\Program Files\Go\bin\go.exe") {
  $Go = "C:\Program Files\Go\bin\go.exe"
}

Write-Host "Building host Windows amd64 binary..."
& $Go build -ldflags "-s -w" -o bin/mf-cli-appsec.exe ./cmd/mf-cli-appsec
Copy-Item bin/mf-cli-appsec.exe bin/mf-cli-appsec-windows-amd64.exe -Force

Write-Host "Cross-compiling other OS targets..."
$env:GOOS = "linux";   $env:GOARCH = "amd64"; & $Go build -ldflags "-s -w" -o bin/mf-cli-appsec-linux-amd64 ./cmd/mf-cli-appsec
$env:GOOS = "linux";   $env:GOARCH = "arm64"; & $Go build -ldflags "-s -w" -o bin/mf-cli-appsec-linux-arm64 ./cmd/mf-cli-appsec
$env:GOOS = "darwin";  $env:GOARCH = "amd64"; & $Go build -ldflags "-s -w" -o bin/mf-cli-appsec-darwin-amd64 ./cmd/mf-cli-appsec
$env:GOOS = "darwin";  $env:GOARCH = "arm64"; & $Go build -ldflags "-s -w" -o bin/mf-cli-appsec-darwin-arm64 ./cmd/mf-cli-appsec
Remove-Item Env:GOOS -ErrorAction SilentlyContinue
Remove-Item Env:GOARCH -ErrorAction SilentlyContinue

Write-Host "Done. Binaries in bin/"
Get-ChildItem bin
