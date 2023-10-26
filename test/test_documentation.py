import subprocess
import os
from .TestUtilities import ROOT_DIR, SCRIPT_DIR, DOCS_DIR


def test_documentation_build_script_exists():
    assert os.path.isdir(ROOT_DIR), "Failed to find repository root directory"
    assert os.path.isdir(SCRIPT_DIR), "Failed to find scripts directory"
    if os.name == 'nt':
        script_file = os.path.join(SCRIPT_DIR, "BuildDocs.ps1")
        assert os.path.isfile(script_file), "BuildDocs.ps1 not found"
    else:
        script_file = os.path.join(SCRIPT_DIR, "BuildDocs.sh")
        assert os.path.isfile(script_file), "BuildDocs.sh not found"


def test_build_documentation():
    """
    Check the documentation builds without errors
    """
    # Reset the docs directory
    if os.path.isdir(DOCS_DIR):
        import shutil
        shutil.rmtree(DOCS_DIR)
    # Check its gone
    assert not os.path.isdir(DOCS_DIR), "Failed to remove docs directory"

    # Add the repository root to the Python path
    scripts_dir = os.path.join(ROOT_DIR, "scripts")

    if os.name == 'nt':
        script_file = os.path.join(scripts_dir, "BuildDocs.ps1")
        output = subprocess.check_output(["powershell", script_file], cwd=scripts_dir, stderr=subprocess.STDOUT)
    else:
        script_file = os.path.join(scripts_dir, "BuildDocs.sh")
        output = subprocess.check_output(script_file, cwd=scripts_dir, shell=True, stderr=subprocess.STDOUT)

    # Check for good vibes message from Sphinx
    assert "build succeeded" in output.decode("utf-8").lower(), "Sphinx build failed"
    # Check for bad vibes message from Sphinx
    assert "error:" not in output.decode("utf-8").lower(), "Error in Sphinx build"
    # Check the output directory exists
    assert os.path.isdir(DOCS_DIR), "Sphinx build failed to create output directory"
    # Check the index.html file exists
    assert os.path.isfile(os.path.join(DOCS_DIR, "index.html")), "Sphinx build failed to create index.html file"


def test_static_assets():
    """Test the static assets are properly copied to the output directory"""
    static_dir = os.path.join(DOCS_DIR, "_static")
    # Check the static directory exists
    assert os.path.isdir(static_dir), "Sphinx build failed to create static directory"
    # Check the logo file exists
    assert os.path.isfile(os.path.join(static_dir, "logo.png")), "Sphinx build failed to copy logo file"
