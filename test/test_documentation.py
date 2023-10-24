import subprocess
import os
from .TestUtilities import get_repo_absolute_path

def test_build_documentation():
    """
    Check the documentation builds without errors
    """


    repo_root = get_repo_absolute_path()
    # Reset the docs directory
    docs_dir = os.path.join(repo_root, "output", "doc")
    if os.path.isdir(docs_dir):
        import shutil
        shutil.rmtree(docs_dir)
    # Check its gone
    assert not os.path.isdir(docs_dir), "Failed to remove docs directory"

    # Add the repository root to the Python path
    scripts_dir = os.path.join(repo_root, "scripts")

    if os.name == 'nt':
        script_file = os.path.join(scripts_dir, "BuildDocs.ps1")
        output = subprocess.check_output(["powershell", script_file], cwd=scripts_dir)
    else:
        script_file = os.path.join(scripts_dir, "BuildDocs.sh")
        output = subprocess.check_output(script_file, cwd=scripts_dir, shell=True)

    # Check for good vibes message from Sphinx
    assert "build succeeded" in output.decode("utf-8").lower(), "Sphinx build failed"
    # Check the output directory exists
    assert os.path.isdir(docs_dir), "Sphinx build failed to create output directory"
    # Check the index.html file exists
    assert os.path.isfile(os.path.join(docs_dir, "index.html")), "Sphinx build failed to create index.html file"



def test_static_assets():
    """Test the static assets are properly copied to the output directory"""
    static_dir = os.path.join(get_repo_absolute_path(), "output", "doc", "_static")
    # Check the static directory exists
    assert os.path.isdir(static_dir), "Sphinx build failed to create static directory"
    # Check the logo file exists
    assert os.path.isfile(os.path.join(static_dir, "logo.png")), "Sphinx build failed to copy logo file"
