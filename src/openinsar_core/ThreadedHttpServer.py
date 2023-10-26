import http.server
import threading
import ssl
from pathlib import Path


class DefaultHandler(http.server.SimpleHTTPRequestHandler):
    def __init__(self, *args, directory=".", **kwargs):
        try:
            super().__init__(*args, directory=directory, **kwargs)
        except ConnectionAbortedError:
            # Otherwise we get lots of runtime errors for 404s
            pass


class ThreadedHttpServer:
    def __init__(
        self,
        host: str = "localhost",
        port: int = 8000,
        server: http.server.ThreadingHTTPServer | None = None,
        thread: threading.Thread | None = None,
        is_https: bool = False,
        directory: str = ".",
        handler: type[http.server.BaseHTTPRequestHandler] | None = DefaultHandler
    ):
        self.host = host
        self.port = port
        self.server = server
        self.thread = thread
        self.is_https = is_https
        self.directory = directory
        self.handler = handler

    def handle_from_directory(self, directory: str | None = None, handler: type[http.server.BaseHTTPRequestHandler] | None = None):
        """Create a handler that serves files from the given directory."""
        # Check we have a handler
        if handler is not None:
            self.handler = handler
        assert self.handler is not None, "No handler provided or initialised"

        # Use directory from initialisation if none is provided
        if directory is None:
            directory = self.directory

        # Return a lambda that creates a handler with the given directory, otherwise we have to subclass the handler with a new __init__ method
        return lambda *args, **kwargs: self.handler(*args, directory=directory, **kwargs)  # type: ignore

    def setup_https(self):
        """Setup HTTPS for the server. This requires a certificate to be available in the same directory as this file."""
        # HTTPS HERE
        try:
            localhost_pem = Path(__file__).with_name("localhost.pem")
        except FileNotFoundError:
            raise FileNotFoundError(
                "The file 'localhost.pem' was not found. Please generate a certificate using the following command: openssl req -new -x509 -keyout localhost.pem -out localhost.pem -days 365 -nodes"
            )
        assert self.server is not None, "Server not initialised"
        self.server.socket = ssl.wrap_socket(
            self.server.socket,
            server_side=True,
            certfile=localhost_pem,
            ssl_version=ssl.PROTOCOL_TLS,
        )

    def setup_http(self):
        assert self.server is not None, "Server not initialised"

    def launch(self, directory: str | None = None):
        """Launch the threaded server. If a directory is provided, it will be served instead of whatever was provided at initialisation."""
        if directory is not None:
            self.directory = directory

        if self.server is None:
            self.server = http.server.ThreadingHTTPServer(
                (self.host, self.port), self.handle_from_directory()
            )

            if self.is_https:
                self.setup_https()
            else:
                self.setup_http()

            # set the thread to run in directory
            self.thread = threading.Thread(
                target=self.server.serve_forever, daemon=True
            )
            self.thread.start()
            print("Serving HTML on http" + ("", "s")[self.is_https] + f"://{self.host}:{self.port}/")

    def stop(self):
        if self.server is not None:
            self.server.shutdown()
            if self.thread is not None:
                self.thread.join()
            self.server = None


if __name__ == "__main__":
    """Example usage"""
    # Initialise the server
    html_server = ThreadedHttpServer("localhost", 8000)
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
