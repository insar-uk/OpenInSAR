import threading
from websockets.sync.server import serve, ServerConnection


def my_echo(conn: ServerConnection):
    """Basic message handler. Echo the message back to the client."""
    for message in conn:
        conn.send(message)
    print("Server handler finished")


class ThreadedWebsocketServer:
    """ A Websocket server that runs in a thread and can be started and stopped at runtime."""
    def __init__(self, port=8765):
        self.port = port
        self.thread = None
        self.server = None  # For shutdown we need a reference to the server object in the thread

    def launch(self):
        """Launch the threaded server."""
        self.thread = threading.Thread(target=self.serve_forever, daemon=True)
        self.server = serve(my_echo, host="localhost", port=self.port)
        self.thread.start()

    def serve_forever(self):
        assert self.server is not None, "Server not initialised"
        self.server.serve_forever()

    def stop(self):
        """Stop the server."""
        if self.thread is not None:
            if self.server is not None:
                self.server.shutdown()
            self.thread.join()
            self.thread = None


if __name__ == "__main__":
    """Example usage"""
    # Initialise the server
    ws_server = ThreadedWebsocketServer(port=8765)
    # Start the server
    ws_server.launch()
    # Do something else, in this case wait for a KeyboardInterrupt
    import time
    while True:
        try:
            time.sleep(1)
        except KeyboardInterrupt:
            break
    # Stop the server
    ws_server.stop()
