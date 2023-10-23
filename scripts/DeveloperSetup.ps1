# Assume we have cloned the repo, and are in the root directory using the following command:
# mkdir blah
# cd blah
# git clone -b dev https://github.com/OpenInSAR-ICL/OpenInSAR.git .

# Check we are in root directory
if (-not (Test-Path .git)) {
    Write-Error "Please run this script from the root directory of the OpenInSAR repository."
    exit
}

# Load helper utilities
. ./scripts/PowershellFunctions.ps1

# Install npm
# https://nodejs.org/en/download/
$npmVersion = Get-InstalledSoftwareVersion -softwareName "Node.js" -commandName "npm"
if ($null -eq $npmVersion) {
    Write-Error "npm is not installed. Please install npm."
    exit
}

# Install python 3.10+
# https://www.python.org/downloads/
$pythonVersion = Get-InstalledSoftwareVersion -softwareName "Python" -commandName "python"
if ($null -eq $pythonVersion) {
    Write-Error "Python is not installed. Please install Python."
    exit
}

# Install python virtual environment
# https://docs.python.org/3/library/venv.html
$pythonVirtualEnv = "venv"
$pythonVirtualEnvPath = "./$pythonVirtualEnv"
if (Test-Path $pythonVirtualEnvPath) {
    Write-Host "Python virtual environment already exists."
} else {
    Write-Host "Creating Python virtual environment."
    python -m venv $pythonVirtualEnv
}

# Activate python virtual environment
$pythonVirtualEnvScript = "$pythonVirtualEnvPath/Scripts/Activate.ps1"
if (Test-Path $pythonVirtualEnvScript) {
    Write-Host "Activating Python virtual environment."
    . $pythonVirtualEnvScript
} else {
    Write-Error "Python virtual environment script not found."
    exit
}

# Check if not in a Python virtual environment
if (-not (Test-Path env:VIRTUAL_ENV)) {
    Write-Error "Not in a Python virtual environment."
    exit
}

# Install python dependencies
$pythonRequirements = "./src/python-requirements.txt"
# Check the requirements file exists
if (Test-Path $pythonRequirements) {
    Write-Host "Installing Python dependencies."
    pip install -r $pythonRequirements
} else {
    Write-Error "Python requirements file not found. It was expected to be found at: $pythonRequirements."
    exit
}
