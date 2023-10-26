# BuildWebApp.ps1: Build the web app

# Get cwd
$startDir = Get-Location

# Set the location to this file's directory
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $here/../src/openinsar_webapp

# Install dependencies
npm install

# Build the web app
npm run build

# Reset the location
Set-Location $startDir
