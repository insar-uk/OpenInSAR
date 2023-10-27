# Example of a long, multi-line command
$command = @"
from time import sleep
from test.TestUtilities import APP_DIR
from src.openinsar_core.SinglePageAppServer import SinglePageApplicationHandler
from src.openinsar_core.ThreadedHttpServer import ThreadedHttpServer

address = \"localhost\"
port = 8000

# Launch the server
spas = ThreadedHttpServer(address, port=port, handler=SinglePageApplicationHandler)
spas.launch(directory=APP_DIR)

# Keep the server running until the user presses some key
print(\"Server running at {address}:{port}\")
print(\"Press any key in the terminal to stop the server\")

# Open the browser to the server
import webbrowser
webbrowser.open(f\"http://{address}:{port}\")

while True:
    try:
        sleep(1)
    except KeyboardInterrupt:
        break

spas.stop()
"@

# Run the command
python -c $command
