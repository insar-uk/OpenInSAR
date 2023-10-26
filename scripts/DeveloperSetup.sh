#!/bin/bash

# Check if in the root directory
if [ ! -d .git ]; then
    echo "Please run this script from the root directory of the OpenInSAR repository."
    exit 1
fi

# Check if npm is installed
if ! command -v npm &> /dev/null; then
    echo "npm is not installed. Please install npm."
    exit 1
fi

# Check if Python is installed
if ! command -v python &> /dev/null; then
    echo "Python is not installed. Please install Python."
    exit 1
fi

# Install python virtual environment
pythonVirtualEnv="venv"
pythonVirtualEnvPath="./$pythonVirtualEnv"
if [ -d $pythonVirtualEnvPath ]; then
    echo "Python virtual environment already exists."
else
    echo "Creating Python virtual environment."
    python -m venv $pythonVirtualEnv
fi

# Activate python virtual environment
pythonVirtualEnvScript="$pythonVirtualEnvPath/bin/activate"
if [ -f $pythonVirtualEnvScript ]; then
    echo "Activating Python virtual environment."
    source $pythonVirtualEnvScript
else
    echo "Python virtual environment script not found."
    exit 1
fi

# Check if not in a Python virtual environment
if [ -z "$VIRTUAL_ENV" ]; then
    echo "Not in a Python virtual environment."
    exit 1
fi

# Install python dependencies
pythonRequirements="./src/python-requirements.txt"
# Check if requirements file exists
if [ -f $pythonRequirements ]; then
    echo "Installing Python dependencies."
    pip install -r $pythonRequirements
else
    echo "Python requirements file not found. It was expected to be found at: $pythonRequirements."
    exit 1
fi

# Grant execute permissions to scripts
chmod +x ./scripts/*.sh
