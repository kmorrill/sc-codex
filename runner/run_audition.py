#!/usr/bin/env python3
"""Run the SuperCollider audition with a hard timeout safeguard."""

import os
import platform
import shutil
import signal
import subprocess
import sys
from datetime import datetime
from pathlib import Path
from typing import Optional

SCLANG = Path("/Applications/SuperCollider.app/Contents/MacOS/sclang")
AUDITION_SCRIPT = (Path(__file__).resolve().parent / "audition.scd").resolve()
AUDIO_CONF = (Path(__file__).resolve().parent / "sclang_conf.yaml").resolve()
AUDIO_RUNTIME = (Path(__file__).resolve().parent / "runtime").resolve()
AUDITION_CAPTURE_DIR = (AUDIO_RUNTIME / "recordings").resolve()
REPO_ROOT = AUDITION_SCRIPT.parent.parent.resolve()
SYNTHS_DIR = (REPO_ROOT / "synths").resolve()
DEFAULT_TIMEOUT = 10.0
DEFAULT_CAPTURE_DEVICE = "MacBook Pro Speakers"


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


def _sanitize_capture_label(value: str) -> str:
    cleaned = [c if c.isalnum() or c in {"-", "_"} else "-" for c in value]
    label = "".join(cleaned).strip("-")
    return label or "audition"


def _start_audio_capture(env: dict[str, str], debug_mode: bool) -> tuple[Optional[subprocess.Popen], Optional[Path]]:
    if platform.system() != "Darwin":
        return (None, None)

    capture_device = env.get("AUDITION_CAPTURE_DEVICE", DEFAULT_CAPTURE_DEVICE).strip()
    if not capture_device:
        if debug_mode:
            print("[audition-runner] audio capture skipped: empty device name", flush=True)
        return (None, None)

    ffmpeg_path = shutil.which("ffmpeg")
    if not ffmpeg_path:
        if debug_mode:
            print("[audition-runner] audio capture skipped: ffmpeg not found", flush=True)
        return (None, None)

    try:
        AUDIO_RUNTIME.mkdir(parents=True, exist_ok=True)
        AUDITION_CAPTURE_DIR.mkdir(parents=True, exist_ok=True)
    except OSError as exc:
        if debug_mode:
            print(f"[audition-runner] audio capture skipped: unable to prepare directories ({exc})", flush=True)
        return (None, None)

    selection = env.get("AUDITION_ONLY", "all").strip() or "all"
    label = _sanitize_capture_label(selection)
    timestamp = datetime.now().strftime("%Y%m%d-%H%M%S")
    output_path = AUDITION_CAPTURE_DIR / f"{timestamp}-{label}.wav"

    cmd = [
        ffmpeg_path,
        "-hide_banner",
        "-loglevel",
        "error",
        "-nostdin",
        "-y",
        "-f",
        "avfoundation",
        "-i",
        f":{capture_device}",
        "-ac",
        "2",
        "-ar",
        "48000",
        "-c:a",
        "pcm_s16le",
        str(output_path),
    ]

    try:
        proc = subprocess.Popen(
            cmd,
            stdin=subprocess.DEVNULL,
            stdout=subprocess.DEVNULL,
            stderr=subprocess.PIPE,
        )
    except FileNotFoundError:
        if debug_mode:
            print("[audition-runner] audio capture skipped: ffmpeg executable missing", flush=True)
        return (None, None)
    except Exception as exc:  # pragma: no cover - defensive logging
        if debug_mode:
            print(f"[audition-runner] audio capture failed to start: {exc}", flush=True)
        return (None, None)

    if debug_mode:
        print(f"[audition-runner] capturing audio to {output_path}", flush=True)

    return (proc, output_path)


def _stop_audio_capture(
    capture: tuple[Optional[subprocess.Popen], Optional[Path]],
    debug_mode: bool,
) -> None:
    proc, output_path = capture
    if proc is None:
        return

    try:
        if proc.poll() is None:
            try:
                proc.send_signal(signal.SIGINT)
                proc.wait(timeout=5)
            except subprocess.TimeoutExpired:
                proc.terminate()
                try:
                    proc.wait(timeout=2)
                except subprocess.TimeoutExpired:
                    proc.kill()
                    proc.wait(timeout=2)
    finally:
        stderr_output = b""
        if proc.stderr is not None:
            try:
                stderr_output = proc.stderr.read()
            finally:
                proc.stderr.close()

        if proc.returncode not in (0, None):
            message = f"[audition-runner] audio capture exited with code {proc.returncode}"
            if stderr_output:
                message = f"{message}: {stderr_output.decode(errors='ignore').strip()}"
            print(message, file=sys.stderr, flush=True)
        elif output_path and output_path.exists():
            print(f"[audition-runner] audio capture saved to {output_path}", flush=True)
        elif debug_mode:
            print("[audition-runner] audio capture produced no output", flush=True)

def main() -> int:
    timeout = float(os.environ.get("AUDITION_TIMEOUT", DEFAULT_TIMEOUT))
    env = os.environ.copy()
    env["SC_AUDITION"] = "1"
    debug_mode = env.get("AUDITION_DEBUG")
    debug_enabled = bool(debug_mode)

    if debug_enabled:
        print("[audition-runner] debug mode enabled", flush=True)

    if not env.get("AUDITION_ONLY"):
        target = _discover_default_target()
        if target:
            env["AUDITION_ONLY"] = target
            print(f"[audition-runner] defaulting to SynthDef '{target}'", flush=True)

    _kill_processes(["sclang", "scsynth"])

    try:
        AUDIO_RUNTIME.mkdir(parents=True, exist_ok=True)
    except OSError as exc:
        if debug_enabled:
            print(f"[audition-runner] unable to ensure runtime directory: {exc}", flush=True)

    capture = _start_audio_capture(env, debug_enabled)

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
        _stop_audio_capture(capture, debug_enabled)
        return 127

    exit_code: int
    try:
        exit_code = proc.wait(timeout=timeout)
    except subprocess.TimeoutExpired:
        print(f"⚠️ Audition exceeded {timeout:.1f}s timeout; terminating SuperCollider session.", file=sys.stderr)
        _terminate_process_group(proc.pid, signal.SIGTERM)
        try:
            exit_code = proc.wait(timeout=5)
        except subprocess.TimeoutExpired:
            _terminate_process_group(proc.pid, signal.SIGKILL)
            try:
                exit_code = proc.wait(timeout=2)
            except subprocess.TimeoutExpired:
                print("⚠️ Unable to fully terminate SuperCollider process tree.", file=sys.stderr)
                exit_code = 124
    finally:
        _stop_audio_capture(capture, debug_enabled)

    return exit_code


if __name__ == "__main__":
    sys.exit(main())
