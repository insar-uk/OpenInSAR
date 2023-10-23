# Check we're in root
if (-not (Test-Path .git)) {
    Write-Error "Run this script from the root of the repository"
    exit 1
}

# Check the virtual environment exists
$venvDir="venv"
if (-not (Test-Path $venvDir)) {
    Write-Error "Virtual environment not found. Run scripts/DeveloperSetup.ps1"
    exit 1
}

# Activate the virtual environment
. $venvDir/Scripts/Activate.ps1
