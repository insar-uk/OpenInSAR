import pytest
from test.TestUtilities import APP_DIR, ROOT_DIR, SCRIPT_DIR, lock_resource
import os
import subprocess

assert lock_resource is not None, "Shutup the linter"


def test_webapp_build_script_exists():
    """Check the build script exists"""
    assert os.path.isdir(ROOT_DIR), "Failed to find repository root directory"
    assert os.path.isdir(SCRIPT_DIR), "Failed to find scripts directory"
    # Run the npm build script
    if os.name == 'nt':
        script_file = os.path.join(SCRIPT_DIR, "BuildWebApp.ps1")
        assert os.path.isfile(script_file), "BuildWebApp.ps1 not found"
    else:
        script_file = os.path.join(SCRIPT_DIR, "BuildWebApp.sh")
        assert os.path.isfile(script_file), "BuildWebApp.sh not found"
    # Check permissions
    assert os.access(script_file, os.X_OK), "BuildWebApp script is not executable"


def test_nodejs_installed():
    """Check NodeJS is installed"""
    try:
        subprocess.check_output(["node", "--version"], shell=True)
    except FileNotFoundError or AssertionError:
        raise AssertionError("NodeJS not installed")


def test_webapp_build():
    """ Check the web app builds without errors """
    # Reset the app directory
    if os.path.isdir(APP_DIR):
        import shutil
        shutil.rmtree(APP_DIR)
    # Check its gone
    assert not os.path.isdir(APP_DIR), "Failed to remove app directory"

    if os.name == 'nt':
        script_file = os.path.join(SCRIPT_DIR, "BuildWebApp.ps1")
        output = subprocess.check_output(["powershell", script_file], cwd=SCRIPT_DIR, stderr=subprocess.STDOUT)
    else:
        script_file = os.path.join(SCRIPT_DIR, "BuildWebApp.sh")
        output = subprocess.check_output(script_file, cwd=SCRIPT_DIR, shell=True, stderr=subprocess.STDOUT)

    # Check the output directory exists
    assert os.path.isdir(APP_DIR), "npm build failed to create output directory"
    # Check for good vibes message from npm
    assert "error:" not in output.decode("utf-8").lower(), "npm build failed"
    # Check the index.html file exists
    assert os.path.isfile(os.path.join(APP_DIR, "index.html")), "npm build failed to create index.html file"


@pytest.mark.parametrize("lock_resource", ["port8002"], indirect=True, ids=["Use port 8002"])  # Mutex for the port
def test_single_page_application(lock_resource):
    """The web app should respond properly to HTTP requests."""
    from src.openinsar_core.SinglePageAppServer import SinglePageApplicationHandler
    from src.openinsar_core.ThreadedHttpServer import ThreadedHttpServer
    import requests

    # Launch the server
    spas = ThreadedHttpServer("localhost", port=8002, handler=SinglePageApplicationHandler)
    spas.launch(directory=APP_DIR)

    # Check the index.html file exists
    assert os.path.isfile(os.path.join(APP_DIR, "index.html")), "npm build failed to create index.html file"

    # Request the index.html file
    response = requests.get("http://localhost:8002")

    # Check the response is good
    assert response.status_code == 200, "Failed to get index.html"
    # Check the response is HTML
    assert "text/html" in response.headers["Content-Type"], "Response was not HTML"
    # Check the response is the index.html file
    assert "I am index.html" in response.text, "Response was not index.html"

    # Now check an invalid path
    response = requests.get("http://localhost:8002/my/invalid/path")
    # Check the response is good
    assert response.status_code == 200, "Failed to get index.html"
    # Check the response is HTML
    assert "text/html" in response.headers["Content-Type"], "Response was not HTML"
    # Check the response is the index.html file
    assert "I am index.html" in response.text, "Response was not index.html"

    spas.stop()
