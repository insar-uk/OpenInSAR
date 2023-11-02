import requests
from src.openinsar_core.ThreadedHttpServer import ThreadedHttpServer
from .TestUtilities import lock_resource
import os
import pytest

assert lock_resource is not None  # Just to shut up the linters who think its unused


@pytest.mark.parametrize("lock_resource", ["port8000"], indirect=True, ids=["Use port 8000"])
def test_https_server(lock_resource):
    """Launch a http server and get a successful response."""
    s = ThreadedHttpServer("localhost", 8000)
    s.launch()
    r = requests.get("http://localhost:8000")
    assert r.status_code == 200
    s.stop()


@pytest.mark.parametrize("lock_resource", ["port8001"], indirect=True, ids=["Use port 8001"])
def test_serve_a_directory(lock_resource):
    """Get this directory, try to serve it, see if we can see this file."""
    thisDir, thisFile = os.path.split(__file__)

    s = ThreadedHttpServer("localhost", 8001, directory=thisDir)
    s.launch()
    r = requests.get("http://localhost:8001")
    assert r.status_code == 200
    assert thisFile in r.text
    s.stop()
