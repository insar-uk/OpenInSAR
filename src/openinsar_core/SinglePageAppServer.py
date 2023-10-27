from os.path import exists
from .ThreadedHttpServer import ThreadedHttpServer
from http.server import SimpleHTTPRequestHandler


class SinglePageApplicationHandler(SimpleHTTPRequestHandler):
    """Redirect all requests to the index.html file. This is useful for single page applications (SPAs) that use client side routing."""
    spa_index = "index.html"

    def do_GET(self):
        """Serve a GET request."""
        # If the path is not a file, assume it's a request for a Vue route and serve index.html
        if not exists(self.translate_path(self.path)):
            self.path = self.spa_index
        # Call the parent class to serve the file
        super().do_GET()


if __name__ == "__main__":
    """Example usage"""
    # Initialise the server
    html_server = ThreadedHttpServer("localhost", 8000, handler=SinglePageApplicationHandler)
    # Start the server
    html_server.launch(directory=".")
    # Do something else, in this case wait for a KeyboardInterrupt
    import time
    while True:
        try:
            time.sleep(1)
        except KeyboardInterrupt:
            break
    # Stop the server
    html_server.stop()
