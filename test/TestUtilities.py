import os


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
