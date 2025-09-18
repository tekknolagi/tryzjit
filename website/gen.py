#!/usr/bin/env python3
# Copyright (c) Meta Platforms, Inc. and affiliates.

import argparse
import html
import http.server
import json
import mimetypes
import os
import re
import shlex
import shutil
import socket
import ssl
import subprocess
import tempfile
import urllib.parse
from xml.etree import ElementTree as ET


TIMEOUT_SEC = 5


def run(
    cmd,
    verbose=True,
    cwd=None,
    check=True,
    capture_output=False,
    encoding="utf-8",
    **kwargs,
):
    if verbose:
        info = "$ "
        if cwd is not None:
            info += f"cd {cwd}; "
        info += " ".join(shlex.quote(c) for c in cmd)
        if capture_output:
            info += " >& ..."
        print(info)
    return subprocess.run(
        cmd,
        cwd=cwd,
        check=check,
        capture_output=capture_output,
        encoding=encoding,
        **kwargs,
    )


TEMPLATE_DIR = os.path.dirname(os.path.realpath(__file__))


def removeprefix(text, prefix):
    if text.startswith(prefix):
        return text[len(prefix) :]
    return text


def removesuffix(text, suffix):
    if text.endswith(suffix):
        return text[: -len(suffix)]
    return text


def find_graphs(stdout):
    graphs = {}
    current_graph = []
    state = "searching"
    result_stdout = []
    for line in stdout.splitlines():
        if state == "searching":
            if line.startswith("digraph G {"):
                state = "reading"
                current_graph = [line]
                name = line.split(" # ")[1]
            else:
                result_stdout.append(line)
        elif state == "reading":
            current_graph.append(line)
            if line.startswith("}"):
                graphs[name] = "\n".join(current_graph)
                state = "searching"
    return graphs, "\n".join(result_stdout)


def make_explorer_class(process_args, prod_hostname=None):
    runtime = args.runtime
    # args.host is for listen address, whereas prod_hostname is for CSP header.
    # If it's set and non-empty, we're in a prod deployment.
    security_headers = {
        "X-Frame-Options": "SAMEORIGIN",
        "X-XSS-Protection": "1; mode=block",
        "X-Content-Type-Options": "nosniff",
    }
    if prod_hostname:
        print("Running a prod deployment...")
        # Don't set HSTS or CSP for local development
        security_headers["Content-Security-Policy"] = (
            f"default-src https://{prod_hostname}/vendor/ http://{prod_hostname}/vendor/ 'self'; "
            "img-src data: 'self';"
            "style-src 'self' 'unsafe-inline';"
            "script-src 'self' 'unsafe-inline'"
        )
        security_headers[
            "Strict-Transport-Security"
        ] = "max-age=31536000; includeSubDomains; preload"

    class ExplorerServer(http.server.SimpleHTTPRequestHandler):
        def _begin_response(self, code, content_type):
            self.send_response(code)
            self.send_header("Content-type", content_type)
            for header, value in security_headers.items():
                self.send_header(header, value)

        def _get_post_params(self):
            content_length = int(self.headers["Content-Length"])
            post_data = self.rfile.read(content_length)
            bytes_params = urllib.parse.parse_qs(post_data)
            str_params = {
                param.decode("utf-8"): [value.decode("utf-8") for value in values]
                for param, values in bytes_params.items()
            }
            return str_params

        def do_GET(self):
            handler = self.routes.get(self.path, self.__class__.do_404)
            return handler(self)

        def do_POST(self):
            self.params = self._get_post_params()
            handler = self.post_routes.get(self.path, self.__class__.do_404)
            return handler(self)

        def do_404(self):
            try:
                static_file = os.path.join(TEMPLATE_DIR, self.path.lstrip("/"))
                content_type = mimetypes.guess_type(static_file)[0] or "text/html"
                with open(static_file, "rb") as f:
                    self._begin_response(200, content_type)
                    self.end_headers()
                    self.wfile.write(f.read())
            except FileNotFoundError:
                self._begin_response(404, "text/html")
                self.end_headers()
                self.wfile.write(f"<b>404 not found: {self.path}</b>".encode("utf-8"))

        def do_compile_get(self):
            self._begin_response(200, "text/html")
            self.end_headers()
            self.wfile.write(b"Waiting for input...")

        def do_helth(self):
            self._begin_response(200, "text/plain")
            self.end_headers()
            self.wfile.write(b"I'm not dead yet")

        def do_explore(self):
            self._begin_response(200, "text/html")
            self.end_headers()
            with open(os.path.join(TEMPLATE_DIR, "explorer.html.in"), "r") as f:
                template = f.read()
            try:
                version_cmd = run(
                    [runtime, "-c", "import sys; print(sys.version)"],
                    capture_output=True,
                )
                version = version_cmd.stdout.partition("\n")[0]
            except Exception:
                version = "unknown"
            template = template.replace("@VERSION@", version)
            self.wfile.write(template.encode("utf-8"))

        def _render_options(self, *options):
            result = []
            for option in options:
                if isinstance(option, str):
                    result.append(option)
                else:
                    result.append("=".join(option))
            return result

        def do_compile_post(self):
            self._begin_response(200, "text/html")
            self.end_headers()
            user_code = self.params["code"][0]
            jit_options = self._render_options(
                "--zjit",
                "--zjit-dump-hir",
                ("--zjit-dump-hir-graphviz", "/dev/stdout"),
                # "--zjit-dump-lir",
                # "--zjit-dump-disasm",
                "--zjit-debug",
                # ("--zjit-num-profiles", 1),
                # ("--zjit-call-threshold", 1),
            )
            timeout = ["timeout", "--signal=KILL", f"{TIMEOUT_SEC}s"]
            with tempfile.TemporaryDirectory() as tmp:
                main_code_path = os.path.join(tmp, "main.rb")
                cmd = [*timeout, runtime, *jit_options, main_code_path]
                pretty_command = b"$ " + " ".join(shlex.quote(c) for c in cmd).encode("utf-8") + b"\n"
                with open(main_code_path, "w+") as f:
                    f.write(user_code)
                try:
                    result = run(
                        cmd,
                        capture_output=True,
                        cwd=tmp,
                    )
                except subprocess.CalledProcessError as e:
                    self.wfile.write(b"<pre>")
                    self.wfile.write(pretty_command)
                    if e.returncode == -9:
                        self.wfile.write(b"Command timed out")
                        return
                    if "SyntaxError" in e.stderr or "StrictModuleError" in e.stderr:
                        escaped = html.escape(e.stderr)
                        self.wfile.write(f"<pre>{escaped}</pre>".encode("utf-8"))
                        return
                    print(e.stderr)
                    self.wfile.write(e.stderr.encode("utf-8"))
                    self.wfile.write(b"</pre>")
                    return
            graphs, stdout = find_graphs(result.stdout)
            self.wfile.write(b"""
<label for="graphviz_functions">Choose a function:</label>
<select id="graphviz_functions">""")
            for name, graph in graphs.items():
                self.wfile.write(f"""<option value="{name}">{name}</option>""".encode("utf-8"))
            self.wfile.write(b"""</select>""")
            for name, graph in graphs.items():
                self.wfile.write(f"""<script type="not-js" id="{name}">{graph}</script>""".encode("utf-8"))
            self.wfile.write(b"""
<div id="graphviz_result"></div>
<script type="module">
  import * as Viz from "./vendor/viz.js";
  const viz = await Viz.instance();
  graphviz_functions.onchange = function () {
    const function_name = graphviz_functions.value;
    const value = document.getElementById(function_name)?.textContent;
    if (value) {
      graphviz_result.innerHTML = '';
      console.log("Rendering graph for", value);
      graphviz_result.appendChild(viz.renderSVGElement(value))
    }
  };
  graphviz_functions.onchange();
</script>
""")
            self.wfile.write(b"<pre>")
            self.wfile.write(pretty_command)
            self.wfile.write(stdout.encode("utf-8"))
            self.wfile.write(b"</pre>")

        routes = {
            "/": do_explore,
            "/compile": do_compile_get,
            "/helth": do_helth,
        }

        post_routes = {
            "/compile": do_compile_post,
        }

    return ExplorerServer


class HTTPServerIPV6(http.server.HTTPServer):
    address_family = socket.AF_INET6


def gen_explorer(args):
    host = args.host
    port = args.port
    explorer_address = (host, port)
    prod_hostname = os.getenv("TRYZJIT_HOSTNAME")
    IRServer = make_explorer_class(args, prod_hostname)
    if args.ipv6:
        httpd = HTTPServerIPV6(explorer_address, IRServer)
    else:
        httpd = http.server.HTTPServer(explorer_address, IRServer)
    print(f"Serving traffic on {host}:{port} ...")
    httpd.serve_forever()


def executable_file(arg):
    if not shutil.which(arg, mode=os.F_OK | os.X_OK):
        parser.error(f"The file {arg} does not exist or is not an executable file")
    return arg


def readable_file(arg):
    if not shutil.which(arg, mode=os.F_OK):
        parser.error(f"The file {arg} does not exist or is not a readable file")
    return arg


def add_server_args(parser):
    parser.add_argument(
        "--host",
        type=str,
        help="Listen address for serving traffic",
        default="::",
    )
    parser.add_argument(
        "--port",
        type=int,
        help="Port for serving traffic",
        default=8081,
    )


if __name__ == "__main__":
    parser = argparse.ArgumentParser(
        description="Generate an HTML visualization of ZJIT IRs"
    )
    parser.add_argument("--perf", type=str, help="JSONified perf events by address")
    subparsers = parser.add_subparsers()

    # Run a Godbolt-style ZJIT Explorer
    explorer_parser = subparsers.add_parser("explorer")
    explorer_parser.add_argument(
        "--runtime",
        type=executable_file,
        help="Path to Ruby runtime",
        default=os.path.expanduser("/app/ruby/ruby"),
    )
    explorer_parser.add_argument(
        "--ipv6",
        action="store_true",
        help="Enable IPv6 support",
    )
    add_server_args(explorer_parser)
    explorer_parser.set_defaults(func=gen_explorer)

    args = parser.parse_args()
    if not hasattr(args, "func"):
        raise Exception("Missing sub-command. See --help.")
    args.func(args)
