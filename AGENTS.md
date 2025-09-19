# Agent Operating Guide

This repo is set up for automated SuperCollider sessions. When acting as the automation agent:

1. **Entry point**: Always start with `make audition`. Boot sclang in daemon mode (`-D`) with the provided config (`runner/sclang_conf.yaml`) so user-level startup scripts are bypassed via `SC_AUDITION=1` and the runner never waits for interactive input. Every invocation runs through a 10 s watchdog. Use `make audition-debug` when you need raw SuperCollider logs or to chase syntax errors; it prints stdout/stderr verbatim while keeping the same timeout protection.
2. **Process hygiene**: Before each run, ensure no previous `sclang`/`scsynth` instances are left over (`pkill sclang`, `pkill scsynth`). The runner expects to control the server lifecycle.
3. **Device targets**: The audition script forces `Server.default` to `MacBook Pro Speakers` output and `MacBook Pro Microphone` input with 48 kHz sample rate and zero input buses; do not override these options unless debugging audio devices.
4. **SynthDef contract**: `synths/*.scd` files must define a `SynthDef(...).add`. Any new file should keep amplitude under 0.3, provide a fast attack/decay envelope, and render in stereo (use `!2` or `Pan2`).
5. **Targeted auditions**: The Python wrapper defaults to auditioning the most recently modified `synths/*.scd` file so you hear just the patch in focus. Set `AUDITION_ONLY` to a comma-separated list (or to `all`) when you need to override this.
6. **Error loop**: If `make audition` fails, always rerun with `make audition-debug` to see SuperCollider’s own messages, then inspect for:
   - missing UGens/classes – either rewrite to stock UGens or build the plugin from `vendor/`.
   - compile syntax errors – fix the offending file and retry.
   - audio boot failures – confirm the device/sample-rate settings.
7. **Timeout behavior**: The Python wrapper enforces a 10 s watchdog so the process never stalls; if you hit the timeout, expect that sclang was waiting for input or a SynthDef couldn’t compile.
8. **Logging**: Keep changes minimal; use `SynthDescLib` before/after snapshots to track new definitions without fully copying the descriptor dictionary.
