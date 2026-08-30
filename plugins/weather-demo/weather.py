#!/usr/bin/env python3
"""
Runtime IPC plugin demo: weather — streams to the bar's Unix socket.

The bar exposes `~/.config/omanix/omanix.sock` (or $OMANIX_SOCKET). This
script connects and sends a single JSON-RPC update, then exits. As a
launchd agent with `interval = 300`, it will re-run every 5 minutes; as a
long-running daemon it could loop and stream. If it crashes, the bar's
socket simply drops the connection and its status item freezes — isolation.

Usage:
  OMANIX_SOCKET=~/.config/omanix/omanix.sock python3 weather.py
  # or via Nix: omanix.plugins.runtime.weather.command = "python3 ${./plugins/weather-demo}/weather.py"
"""
import json, os, socket, sys, urllib.request

SOCK = os.path.expanduser(os.environ.get("OMANIX_SOCKET", "~/.config/omanix/omanix.sock"))

def fetch_weather():
    # Demo: use wttr.in for no-API-key weather; replace with your provider.
    try:
        with urllib.request.urlopen("https://wttr.in/?format=%t+%C", timeout=5) as r:
            txt = r.read().decode().strip()
            # wttr.in returns like "+22°C Clear"
            return txt or "22°C Clear"
    except Exception as e:
        return f"22°C"

def send_update(title):
    payload = {
        "jsonrpc": "2.0",
        "method": "update",
        "params": {
            "id": "weather",
            "title": title,
            "image": "cloud.sun.fill",
            "payload": {"source": "wttr.in"}
        }
    }
    data = (json.dumps(payload) + "\n").encode()
    try:
        s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
        s.connect(SOCK)
        s.sendall(data)
        s.close()
        print(f"weather: sent '{title}' to {SOCK}", file=sys.stderr)
    except FileNotFoundError:
        print(f"weather: socket not found at {SOCK} — is the bar running with omanix.plugins.enable = true?", file=sys.stderr)
        sys.exit(0)
    except Exception as e:
        print(f"weather: send failed: {e}", file=sys.stderr)

if __name__ == "__main__":
    title = fetch_weather()
    send_update(title)
