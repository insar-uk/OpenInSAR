#!/bin/bash

# Get current working directory
startDir=$(pwd)

# Set the location to this file's directory
here="$(dirname "$(readlink -f "$0")")"
cd "$here/../src/openinsar_webapp" || exit

# Install npm packages
npm install

# Run npm
npm run build

# Reset the location
cd "$startDir" || exit
