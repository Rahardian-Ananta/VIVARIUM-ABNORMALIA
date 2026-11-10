#!/usr/bin/env python3
"""
Simple HTTP server with Cross-Origin Isolation headers (COOP/COEP)
Required for testing Godot 4 HTML5 WebAssembly builds locally.
"""

import http.server
import socketserver
import os
import sys

PORT = 8080
DIRECTORY = os.path.join(os.path.dirname(__file__), "build", "web")

class CrossOriginIsolatedHandler(http.server.SimpleHTTPRequestHandler):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory=DIRECTORY, **kwargs)

    def end_headers(self):
        # Enable SharedArrayBuffer & WebAssembly threading
        self.send_header("Cross-Origin-Opener-Policy", "same-origin")
        self.send_header("Cross-Origin-Embedder-Policy", "require-corp")
        self.send_header("Cache-Control", "no-cache, no-store, must-revalidate")
        super().end_headers()

def main():
    if not os.path.exists(DIRECTORY):
        os.makedirs(DIRECTORY, exist_ok=True)
        print(f"Created export folder: {DIRECTORY}")
        print("Export the project from Godot Engine to this directory first (Project -> Export -> Web).")

    print(f"Serving Godot 4 Web build from: {DIRECTORY}")
    print(f"Open your browser at: http://localhost:{PORT}")
    print("Press Ctrl+C to stop.")

    socketserver.TCPServer.allow_reuse_address = True
    with socketserver.TCPServer(("", PORT), CrossOriginIsolatedHandler) as httpd:
        try:
            httpd.serve_forever()
        except KeyboardInterrupt:
            print("\nServer stopped.")

if __name__ == "__main__":
    main()
