# Unsolved Challenges

1. **Runner execution halts at the prompt** – Sometimes sclang boots, prints the banner, and sits at `sc3>` without running our audition block. We still need a bulletproof solution (maybe `-D` daemon mode or a different code wrapper).
2. **SynthDef discovery is inconsistent** – `SynthDescLib` key diffs haven’t yet picked up the real `\bleep` def; the runner keeps installing its fallback.
3. **Device selection drift** – Even after forcing the MBP speaker/mic pair, macOS occasionally routes back to AirPods/24 kHz inputs, triggering boot failures. A deterministic way to enforce devices at runtime is still pending.
4. **Plugin dependencies** – Startup scripts referencing `MiPlaits`, `MiRings`, `MiClouds`, or SuperDirt keep warning about missing UGens. A stock fallback or automated plugin build remains to be done.
5. **Headless exit noise** – Feeding code via stdin yields thousands of `Exiting sclang (ctrl-D)` messages. Cleaning this up would make logs easier to scan and might expose other exit issues.

