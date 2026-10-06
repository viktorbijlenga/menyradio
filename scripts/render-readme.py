#!/usr/bin/env python3
"""Render the local README image using a temporary headless Chrome profile."""
import os
from pathlib import Path
import signal
import subprocess
import tempfile
import time

root = Path(__file__).resolve().parent.parent
output = root / "docs/images/menu-preview-v0.3.0.png"
chrome = "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
started = time.time()
with tempfile.TemporaryDirectory(prefix="menyradio-readme-") as profile:
    process = subprocess.Popen([
        chrome, "--headless", "--disable-gpu", "--disable-background-networking",
        "--no-first-run", "--no-default-browser-check", "--hide-scrollbars",
        "--allow-file-access-from-files", f"--user-data-dir={profile}",
        f"--screenshot={output}", "--window-size=800,440", "--force-device-scale-factor=2",
        (root / "docs/images/menu-preview.html").as_uri(),
    ], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, start_new_session=True)
    try:
        process.wait(timeout=12)
    except subprocess.TimeoutExpired:
        os.killpg(process.pid, signal.SIGTERM)
        try:
            process.wait(timeout=3)
        except subprocess.TimeoutExpired:
            os.killpg(process.pid, signal.SIGKILL)
            process.wait()
    if not output.exists() or output.stat().st_mtime < started:
        raise SystemExit("Chrome did not produce the README image")
print(output)
