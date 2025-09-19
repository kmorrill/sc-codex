#!/usr/bin/env python3
"""Run the SuperCollider audition with a hard timeout safeguard."""

import os
import signal
import subprocess
import sys
from pathlib import Path
from typing import Optional

SCLANG = Path("/Applications/SuperCollider.app/Contents/MacOS/sclang")
AUDITION_SCRIPT = (Path(__file__).resolve().parent / "audition.scd").resolve()
AUDIO_CONF = (Path(__file__).resolve().parent / "sclang_conf.yaml").resolve()
AUDIO_RUNTIME = (Path(__file__).resolve().parent / "runtime").resolve()
REPO_ROOT = AUDITION_SCRIPT.parent.parent.resolve()
SYNTHS_DIR = (REPO_ROOT / "synths").resolve()
DEFAULT_TIMEOUT = 10.0


def _kill_processes(names: list[str]) -> None:
    for name in names:
        try:
            subprocess.run(["pkill", name], check=False, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        except FileNotFoundError:
            # pkill may not exist on all platforms; ignore if missing
            continue


def _terminate_process_group(pid: int, first_signal: int = signal.SIGTERM) -> None:
    if pid <= 0:
        return
    try:
        os.killpg(pid, first_signal)
    except ProcessLookupError:
        return

def _discover_default_target() -> Optional[str]:
    if not SYNTHS_DIR.exists():
        return None
    scd_files = sorted(
        SYNTHS_DIR.glob("*.scd"),
        key=lambda p: p.stat().st_mtime,
        reverse=True,
    )
    for path in scd_files:
        stem = path.stem.strip()
        if stem:
            return stem
    return None


def main() -> int:
    timeout = float(os.environ.get("AUDITION_TIMEOUT", DEFAULT_TIMEOUT))
    env = os.environ.copy()
    env["SC_AUDITION"] = "1"
    debug_mode = env.get("AUDITION_DEBUG")

    if debug_mode:
        print("[audition-runner] debug mode enabled", flush=True)

    if not env.get("AUDITION_ONLY"):
        target = _discover_default_target()
        if target:
            env["AUDITION_ONLY"] = target
            print(f"[audition-runner] defaulting to SynthDef '{target}'", flush=True)

    _kill_processes(["sclang", "scsynth"])

    cmd = [
        str(SCLANG),
        "-D",
        "-d",
        str(AUDIO_RUNTIME),
        "-l",
        str(AUDIO_CONF),
        str(AUDITION_SCRIPT),
    ]

    try:
        proc = subprocess.Popen(cmd, env=env, preexec_fn=os.setsid)
    except FileNotFoundError:
        print(f"Could not find sclang executable at {SCLANG}", file=sys.stderr)
        return 127

    try:
        return proc.wait(timeout=timeout)
    except subprocess.TimeoutExpired:
        print(f"⚠️ Audition exceeded {timeout:.1f}s timeout; terminating SuperCollider session.", file=sys.stderr)
        _terminate_process_group(proc.pid, signal.SIGTERM)
        try:
            return proc.wait(timeout=5)
        except subprocess.TimeoutExpired:
            _terminate_process_group(proc.pid, signal.SIGKILL)
            try:
                return proc.wait(timeout=2)
            except subprocess.TimeoutExpired:
                print("⚠️ Unable to fully terminate SuperCollider process tree.", file=sys.stderr)
                return 124


if __name__ == "__main__":
    sys.exit(main())
