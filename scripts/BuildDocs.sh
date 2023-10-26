#!/bin/bash

# Get current working directory
startDir=$(pwd)

# Set the location to this file's directory
here="$(dirname "$(readlink -f "$0")")"
cd "$here/../doc" || exit

# Generate Sphinx source files from code in the repository
# Output directory: 'root/doc/source'
# Input directory: 'root/src'
sphinx-apidoc -o source/ ../src
sphinx-apidoc -o source/ ../test

# Build the HTML documentation
# Build html files
# Sphinx source directory: 'root/doc/source' (contains conf.py)
# Output directory: 'root/doc/build'
# -M html: Build HTML files
# -E: Ignore cached files
# -a: Force all files to be re-built
sphinx-build -M html source build -E -a

# Remove the old HTML files
if [ -d ../output/doc ]; then
    rm -r ../output/doc
fi

# Copy the HTML files to the output directory
if [ ! -d ../output/doc ]; then
    mkdir ../output/doc
fi
cp -r build/html/* ../output/doc/

# Reset the location
cd "$startDir" || exit
