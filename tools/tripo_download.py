#!/usr/bin/env python3
"""Tripo AI 3D Model Downloader — Downloads generated GLB models."""

import os
import sys
import json
import time
import urllib.request

API_KEY = os.environ.get("TRIPO_API_KEY", "")
BASE_URL = "https://api.tripo3d.ai/v2/openapi"
OUTPUT_DIR = os.path.join(os.path.dirname(__file__), "output")

def check_task(task_id: str) -> dict:
    req = urllib.request.Request(
        f"{BASE_URL}/task/{task_id}",
        headers={"Authorization": f"Bearer {API_KEY}"}
    )
    with urllib.request.urlopen(req) as resp:
        return json.loads(resp.read())

def wait_for_task(task_id: str, name: str, poll_interval: float = 5.0) -> dict:
    print(f"[{name}] Waiting for task {task_id}...")
    while True:
        result = check_task(task_id)
        data = result.get("data", {})
        status = data.get("status", "unknown")
        progress = data.get("progress", 0)

        if status == "success":
            print(f"[{name}] Done!")
            return data
        elif status == "failed":
            print(f"[{name}] FAILED: {data}")
            return data
        else:
            print(f"[{name}] {status} ({progress}%)")
            time.sleep(poll_interval)

def download_model(task_data: dict, name: str):
    result = task_data.get("result", {})
    model_url = result.get("model", {}).get("url", "")
    if not model_url:
        # Try alternative paths
        model_url = result.get("pbr_model", {}).get("url", "")
    if not model_url:
        print(f"[{name}] No model URL found in result!")
        print(f"[{name}] Result keys: {list(result.keys())}")
        return None

    os.makedirs(OUTPUT_DIR, exist_ok=True)
    filename = f"{name}.glb"
    filepath = os.path.join(OUTPUT_DIR, filename)

    print(f"[{name}] Downloading to {filepath}...")
    urllib.request.urlretrieve(model_url, filepath)
    size_mb = os.path.getsize(filepath) / (1024 * 1024)
    print(f"[{name}] Saved ({size_mb:.1f} MB)")
    return filepath

def main():
    if not API_KEY:
        # Try loading from .env
        env_path = os.path.join(os.path.dirname(__file__), "..", ".env")
        if os.path.exists(env_path):
            with open(env_path) as f:
                for line in f:
                    if line.startswith("TRIPO_API_KEY="):
                        globals()["API_KEY"] = line.strip().split("=", 1)[1]
                        break

    if len(sys.argv) < 2:
        print("Usage: python tripo_download.py <name>=<task_id> [name2=task_id2] ...")
        print("Example: python tripo_download.py chest=abc-123 fruit=def-456")
        sys.exit(1)

    tasks = {}
    for arg in sys.argv[1:]:
        if "=" in arg:
            name, task_id = arg.split("=", 1)
            tasks[name] = task_id
        else:
            tasks[arg] = arg

    for name, task_id in tasks.items():
        data = wait_for_task(task_id, name)
        if data.get("status") == "success":
            download_model(data, name)

if __name__ == "__main__":
    main()
