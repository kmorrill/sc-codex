# Agent Operating Guide

This repo is set up for automated SuperCollider sessions. When acting as the automation agent:

1. **Entry point**: Always start with `make audition`. Boot sclang with the provided config (`runner/sclang_conf.yaml`) so user-level startup scripts are bypassed via `SC_AUDITION=1`.
2. **Process hygiene**: Before each run, ensure no previous `sclang`/`scsynth` instances are left over (`pkill sclang`, `pkill scsynth`). The runner expects to control the server lifecycle.
3. **Device targets**: The audition script forces `Server.default` to `MacBook Pro Speakers` output and `MacBook Pro Microphone` input with 48 kHz sample rate and zero input buses; do not override these options unless debugging audio devices.
4. **SynthDef contract**: `synths/*.scd` files must define a `SynthDef(...).add`. Any new file should keep amplitude under 0.3, provide a fast attack/decay envelope, and render in stereo (use `!2` or `Pan2`).
5. **Error loop**: If `make audition` fails, inspect the log for:
   - missing UGens/classes – either rewrite to stock UGens or build the plugin from `vendor/`.
   - compile syntax errors – fix the offending file and retry.
   - audio boot failures – confirm the device/sample-rate settings.
6. **Timeout behavior**: The runner exits after ~6 s per SynthDef (audition routine plus cleanup). If it hangs, check for server boot failure or scripts that don’t `0.exit`.
7. **Logging**: Keep changes minimal; use `SynthDescLib` before/after snapshots to track new definitions without fully copying the descriptor dictionary.

