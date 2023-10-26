import os
import pytest
import threading

LOCKING_RESOURCES: dict[str, threading.Lock] = {}


@pytest.fixture
def lock_resource(request: pytest.FixtureRequest):
    assert request.param is not None, "The name of the resource to lock must be provided"
    assert isinstance(request.param, str), "The name of the resource to lock must be a string"
    resource_name = request.param

    if resource_name not in LOCKING_RESOURCES:
        LOCKING_RESOURCES[resource_name] = threading.Lock()

    lock = LOCKING_RESOURCES[resource_name]

    def acquire_lock():
        lock.acquire()

    def release_lock():
        lock.release()

    request.addfinalizer(release_lock)
    acquire_lock()
    yield
    release_lock()


def get_repo_absolute_path() -> str:
    # get the location of this file
    this_file = os.path.realpath(__file__)
    # get the location of the root of the repository
    root = os.path.dirname(os.path.dirname(this_file))
    return root


def app_dir():
    repo_root = get_repo_absolute_path()
    return os.path.join(repo_root, "output", "app")


def script_dir():
    repo_root = get_repo_absolute_path()
    return os.path.join(repo_root, "scripts")


def docs_dir():
    repo_root = get_repo_absolute_path()
    return os.path.join(repo_root, "output", "doc")


ROOT_DIR = get_repo_absolute_path()
SCRIPT_DIR = script_dir()
APP_DIR = app_dir()
DOCS_DIR = docs_dir()
