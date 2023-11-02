import subprocess
import os
from .TestUtilities import ROOT_DIR, SCRIPT_DIR, DOCS_DIR
import pytest


def test_documentation_build_script_exists():
    """Looks for the documentation build script, script/BuildDocs.ps1 or script/BuildDocs.sh"""
    assert os.path.isdir(ROOT_DIR), "Failed to find repository root directory"
    assert os.path.isdir(SCRIPT_DIR), "Failed to find scripts directory"
    if os.name == "nt":
        script_file = os.path.join(SCRIPT_DIR, "BuildDocs.ps1")
        assert os.path.isfile(script_file), "BuildDocs.ps1 not found"
    else:
        script_file = os.path.join(SCRIPT_DIR, "BuildDocs.sh")
        assert os.path.isfile(script_file), "BuildDocs.sh not found"


@pytest.fixture
def check_sphinx_apidoc(tmp_path):
    """See (func: test_sphinx_apidoc)"""
    def _check_sphinx_apidoc(module_name, expected_content):
        # Define paths
        module_path = tmp_path / f"{module_name}.py"
        output_dir = tmp_path / "docs"
        output_file_path = output_dir / f"{module_name}.rst"

        try:
            # Create a new Python module
            with open(module_path, "w") as f:
                f.write(
                    f'def sample_function():\n    """{expected_content}"""\n    pass\n'
                )

            # Run sphinx-apidoc command. Check return code is 0
            process = subprocess.run(
                ["sphinx-apidoc", "-o", str(output_dir), str(tmp_path)],
                capture_output=True,
                text=True,
            )
            # Get the combined stdout/stderr
            combined_output = process.stdout + process.stderr
            # Check the return code is 0
            assert (
                process.returncode == 0
            ), f"sphinx-apidoc failed with return code {process.returncode}. Output:\n{combined_output}"

            # Check if the output file exists
            assert (
                output_file_path.exists()
            ), f"Output file {output_file_path} does not exist."

            # Check if the output file contains the expected content
            with open(output_file_path, "r") as f:
                content = f.read()
                assert (
                    f".. automodule:: {module_name}" in content
                ), "Expected automodule directive, but not found in the output file."
        except Exception as e:
            pytest.fail(f"An error occurred: {e}")
        finally:
            # Clean up
            if module_path.exists():
                os.remove(module_path)
            if output_file_path.exists():
                os.remove(output_file_path)
    yield _check_sphinx_apidoc
    # Remove the temporary directory
    if tmp_path.exists():
        import shutil
        shutil.rmtree(tmp_path)


# Usage of the fixture
def test_sphinx_apidoc(check_sphinx_apidoc):
    """Creates a new Python module and runs sphinx-apidoc on it. Checks the output file contains the expected content."""
    module_name = "sample_module"  # Replace with your module name
    expected_content = "Sample Docstring"  # Replace with your expected content
    check_sphinx_apidoc(module_name, expected_content)


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

    if os.name == "nt":
        script_file = os.path.join(scripts_dir, "BuildDocs.ps1")
        output = subprocess.check_output(
            ["powershell", script_file], cwd=scripts_dir, stderr=subprocess.STDOUT
        )
    else:
        script_file = os.path.join(scripts_dir, "BuildDocs.sh")
        output = subprocess.check_output(
            script_file, cwd=scripts_dir, shell=True, stderr=subprocess.STDOUT
        )

    # Check for good vibes message from Sphinx
    assert "build succeeded" in output.decode("utf-8").lower(), "Sphinx build failed"
    # Check for bad vibes message from Sphinx
    assert "error:" not in output.decode("utf-8").lower(), "Error in Sphinx build"
    # Check the output directory exists
    assert os.path.isdir(DOCS_DIR), "Sphinx build failed to create output directory"
    # Check the index.html file exists
    assert os.path.isfile(
        os.path.join(DOCS_DIR, "index.html")
    ), "Sphinx build failed to create index.html file"


def test_static_assets():
    """Test the static assets are properly copied to the output directory"""
    static_dir = os.path.join(DOCS_DIR, "_static")
    # Check the static directory exists
    assert os.path.isdir(static_dir), "Sphinx build failed to create static directory"
    # Check the logo file exists
    assert os.path.isfile(
        os.path.join(static_dir, "logo.png")
    ), "Sphinx build failed to copy logo file"
