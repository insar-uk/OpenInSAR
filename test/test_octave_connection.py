import pytest
import subprocess


def found_octave():
    """Check if octave is installed"""
    try:
        subprocess.check_output(["octave-cli", "--version"], shell=True)
        return True
    except FileNotFoundError or AssertionError:
        return False

@pytest.mark.skipif(not found_octave(), reason="Octave not found on command line")
def test_command_octave():
    """Call Octave script from python. Skips if octave-cli is not available on the command line."""

    # Get the path to the octave binary
    octave_path = 'octave-cli'
    command = "disp('hello from octave')"

    # Run the octave command
    o = subprocess.check_output([octave_path, "--eval", command], shell=True)

    # Decode the output
    o = o.decode('utf-8')

    # Check if the output is correct
    assert 'hello from octave' in o.lower(), "Octave did not respond as expected"
