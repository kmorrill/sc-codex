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

- `make audition` boots `sclang`, compiles everything under `synths/`, and plays a 4-note demo for any new SynthDef it finds.
- `make watch` (requires `entr`) re-runs the audition whenever synth files change.
- `make boot` launches `scsynth` manually on the default port in case you want to drive it from an editor.

### Current state

`runner/audition.scd` forces a 48 kHz session on the MacBook Pro speaker/mic pair, disables input buses for stability, and logs which SynthDefs were discovered. Build scripts still prioritize stock UGens; plugin-dependent definitions should provide fallbacks.

