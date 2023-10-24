# Sphinx documentation generator

OpenInSAR uses the Sphinx python package for generating documentation. Ideally everything required for this should be contained in this folder.

The [Sphinx documentation](https://www.sphinx-doc.org/en/master/usage/installation.html) can provide further usage information.

## Usage

Install and run Sphinx in a virtual environment. To activate the virtual environment, run `venv/bin/activate` (Linux) or `venv\Scripts\activate.bat` (Windows).

Build and run the documentation with:

```bash
cd doc
# sphinx-apidoc: Generate Sphinx source files from code in the repository
#   -o source/: Output directory ('root/doc/source')
#   ../src/: Input directory ('root/src')
sphinx-apidoc -o source/ ../src/
# sphinx-build: Build the html documentation
#   -M html: build html files
#   source: Sphinx source directory ('root/doc/source', contains conf.py)
#   build: Output directory ('root/doc/build')
sphinx-build -M html source build
# Copy the html files to the output directory
cp -r build/html/* ../output/doc/
```

