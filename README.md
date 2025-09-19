# SuperCollider Codex

This repository is the sandbox for "Codex" sessions: we craft and audition SuperCollider `SynthDef`s quickly without having to hand-drive sclang each time. It grew out of a simple charter:

1. **Vibe coding** – Iterate on synth designs, focusing on timbre exploration rather than full compositions.
2. **Fast audition loop** – Every `make audition` run should boot SuperCollider, load all `synths/*.scd`, and play short reference phrases so new ideas can be heard immediately.
3. **Minimal dependencies** – Prefer stock UGens and guard against developer-machine startup scripts that pull in heavy quarks/plugins unless we explicitly need them.

### Layout

```
synths/         # individual SynthDef files (each must `.add`) 
runner/         # audition runner script, local runtime/config assets
vendor/         # sc3-plugins, mi-ugens submodules (only built when needed)
Makefile        # automation entry points (audition, boot, watch)
```

### Usage

- `make audition` boots `sclang` **in daemon mode** (`-D`), compiles everything under `synths/`, and auditions only one SynthDef by default. The wrapper picks the most recently modified `synths/*.scd` file (usually the patch you are working on) and plays a short reference phrase for that definition. Every run is wrapped in a 10 s watchdog so the session never hangs.
- `make audition-debug` runs the same session through the timeout harness but leaves stdout/stderr unfiltered so you can inspect syntax errors and runtime warnings directly. Any SuperCollider parse failures will show up here immediately; fix the offending file and rerun.
- `make watch` (requires `entr`) re-runs the audition whenever synth files change.
- `make boot` launches `scsynth` manually on the default port in case you want to drive it from an editor.

Set `AUDITION_ONLY` to override the default target. Examples:

```bash
# audition a specific synth
AUDITION_ONLY=bass_simple make audition

# audition multiple synths in sequence
AUDITION_ONLY="bass_simple,soft_pad" make audition

# fall back to auditioning every SynthDef
AUDITION_ONLY=all make audition
```

### Current state

`runner/audition.scd` forces a 48 kHz session on the MacBook Pro speaker/mic pair, disables input buses for stability, and logs which SynthDefs were discovered. Build scripts still prioritize stock UGens; plugin-dependent definitions should provide fallbacks.

### Iteration tips

- Put new ideas in their own `synths/*.scd`; each file must `SynthDef(...).add`.
- Use `make audition` for the fast loop, `make audition-debug` whenever you need raw error output.
- Syntax errors stop the interpreter before your code runs; look for `ERROR: Parse error` in debug output, fix the file, and rerun.
- Runtime exceptions inside a SynthDef will surface as `SynthDef not found` if compilation failed—fix the `.scd` file then re-audition.
