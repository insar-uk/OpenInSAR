import os


def get_repo_absolute_path() -> str:
    # get the location of this file
    this_file = os.path.realpath(__file__)
    # get the location of the root of the repository
    root = os.path.dirname(os.path.dirname(this_file))
    return root