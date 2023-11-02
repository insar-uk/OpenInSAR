import pytest
from src.openinsar_core.ThreadedWebsocketServer import ThreadedWebsocketServer
from test.TestUtilities import lock_resource
from websockets.sync.client import connect

assert lock_resource is not None  # Just to shut up the linters who think its unused


def client_send_recieve(message_to_send: str, port: int, address: str = "localhost", is_wss: bool = False) -> str:
    """Create a client, send a message, receive a message, close the client, return the message."""
    # Create a websocket client
    protocol = "wss" if is_wss else "ws"
    server_uri = f"{protocol}://{address}:{port}"
    conn = connect(server_uri)
    assert conn is not None, "Failed to connect to websocket server"
    # Send a message
    conn.send(message_to_send)
    # Receive a message
    result = conn.recv()
    # Assert the message is correct
    assert isinstance(result, str)
    # Close the client
    conn.close()
    return result


@pytest.mark.parametrize("lock_resource", ["port8765"], indirect=True, ids=["Use port 8765"])  # Mutex for the port
def test_websocket_server(lock_resource):
    """Test setting up the websocket server and receiving a message"""
    ws_server = ThreadedWebsocketServer(port=8765)
    ws_server.launch()
    # Send a message
    result = client_send_recieve("Hello, World!", 8765)
    assert result == "Hello, World!"
    # Stop the server
    ws_server.stop()


@pytest.mark.parametrize("lock_resource", ["port8766"], indirect=True, ids=["Use port 8766"])  # Mutex for the port
def test_websocket_echo(lock_resource):
    """Test echoing a message back from the server"""
    ws_server = ThreadedWebsocketServer(port=8766)
    ws_server.launch()
    # Send a message
    result = client_send_recieve("Hello, World!", 8766)
    assert result == "Hello, World!"
    # Stop the server
    ws_server.stop()
