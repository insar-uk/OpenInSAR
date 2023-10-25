# Configuration file for the Sphinx documentation builder.
#
# For the full list of built-in configuration values, see the documentation:
# https://www.sphinx-doc.org/en/master/usage/configuration.html

import os
import sys

# -- Project information -----------------------------------------------------
# https://www.sphinx-doc.org/en/master/usage/configuration.html#project-information

project = 'OpenInSAR'
copyright = '2023, Stewart Agar'
author = 'Stewart Agar'
release = '0.1'

# -- General configuration ---------------------------------------------------
# https://www.sphinx-doc.org/en/master/usage/configuration.html#general-configuration

# Get path of this file
this_dir = os.path.dirname(os.path.realpath(__file__))
# Get path of the root of the repository, relative to this file
repo_root = os.path.dirname(os.path.dirname(this_dir))
repo_root = os.path.abspath(repo_root)
# Add the repository root to the Python path
sys.path.insert(0, repo_root)
# Add sub-packages to the Python path
sys.path.insert(0, os.path.join(repo_root, "src"))

extensions = [
    'sphinx.ext.autodoc',
    'sphinx.ext.duration',
    'sphinx.ext.intersphinx',
    'sphinx.ext.autosummary'
]

templates_path = ['templates']
exclude_patterns = ['build', 'Thumbs.db', '.DS_Store']

# -- Intersphinx configuration -----------------------------------------------
# Configure intersphinx_mapping links to other sphinx documentation
intersphinx_mapping = {
    'python': ('https://docs.python.org/3', None),  # Python standard library
    'websockets': ('https://websockets.readthedocs.io/en/stable/', None),  # Websockets
    'numpy': ('https://numpy.org/doc/stable/', None)  # Numpy
}

# -- Options for HTML output -------------------------------------------------
# https://www.sphinx-doc.org/en/master/usage/configuration.html#options-for-html-output

html_theme = 'alabaster'
html_static_path = ['static/']
html_logo = '../../res/logo/logo.png'
html_css_files = ['static/custom.css']
html_js_files = ['custom.js']

# -- Options for sidebars ----------------------------------------------------
# https://www.sphinx-doc.org/en/master/usage/configuration.html#options-for-sidebars

html_sidebars = {
    '**': [
        'about.html',
        'navigation.html',
        'relations.html',
        'searchbox.html',
    ]
}
