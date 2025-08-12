#!/usr/bin/env python3
import http.server
import socketserver
import json
import os
import sys

# Add the current directory to Python path to import process_documents
sys.path.append(os.path.dirname(os.path.abspath(__file__)))

try:
    from process_documents import get_document_comparison
except ImportError:
    # Fallback if import fails
    get_document_comparison = None

class HealthHandler(http.server.BaseHTTPRequestHandler):
    def do_GET(self):
        if self.path == "/health":
            self.send_response(200)
            self.send_header("Content-type", "text/plain")
            self.end_headers()
            self.wfile.write(b"healthy")
        
        elif self.path.startswith("/demo/compare/"):
            # Extract filename from path: /demo/compare/filename
            filename = self.path.split("/demo/compare/")[-1]
            if not filename:
                self.send_response(400)
                self.send_header("Content-type", "application/json")
                self.end_headers()
                self.wfile.write(json.dumps({"error": "No filename provided"}).encode())
                return
            
            if get_document_comparison:
                try:
                    comparison = get_document_comparison(filename)
                    self.send_response(200)
                    self.send_header("Content-type", "application/json")
                    self.end_headers()
                    self.wfile.write(json.dumps(comparison, indent=2).encode())
                except Exception as e:
                    self.send_response(500)
                    self.send_header("Content-type", "application/json")
                    self.end_headers()
                    self.wfile.write(json.dumps({"error": str(e)}).encode())
            else:
                self.send_response(503)
                self.send_header("Content-type", "application/json")
                self.end_headers()
                self.wfile.write(json.dumps({"error": "Comparison service not available"}).encode())
        
        else:
            self.send_response(404)
            self.send_header("Content-type", "application/json")
            self.end_headers()
            self.wfile.write(json.dumps({"error": "Endpoint not found"}).encode())

if __name__ == "__main__":
    with socketserver.TCPServer(("", 8081), HealthHandler) as httpd:
        print("Health server started on port 8081")
        print("Available endpoints:")
        print("  GET /health - Health check")
        print("  GET /demo/compare/{filename} - Compare original vs protected document")
        httpd.serve_forever() 