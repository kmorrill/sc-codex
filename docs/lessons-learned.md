# Lessons Learned

## Timeout discipline
- Wrap `make audition` in a 20–60 s timeout (`subprocess.run(..., timeout=...)` or `timeout` CLI). Kill lingering `sclang`/`scsynth` when it triggers, and inspect logs instead of waiting forever.
- Keep the audition routine itself short (≈6 s per SynthDef) and schedule a matching SuperCollider timeout so the script self-terminates on hangs.

## Device boot issues
- Mismatched input/output sample rates (e.g. AirPods defaulting to 24 kHz) make the server refuse to boot. For automation, set `Server.default.options.numInputBusChannels = 0`, target `MacBook Pro Speakers`, and enforce 48 kHz.
- If CoreAudio rejects the combined `device`, leave `options.device = nil` but set `options.inDevice`/`options.outDevice` explicitly.

## Startup isolation
- User startup files often load SuperDirt or custom UGens. Guard them with `if("SC_AUDITION".getenv.isNil)` so automated runs stay lean.
- Use a repo-local `sclang_conf.yaml` that excludes downloaded quark paths (SuperDirt, Dirt-Samples, etc.) to keep the class library minimal.

## SynthDef tracking
- Compare `SynthDescLib.global.synthDescs.keys` before and after compiling `synths/*.scd` to find new definitions. Avoid copying entire descriptor dictionaries; the lighter key comparison prevents hangs.

## Troubleshooting flow
- If only the SuperCollider banner appears, our script never executed—double-check parentheses and ensure the outermost block is evaluated (`...).value`).
- For audio issues, first run a standalone boot script with the desired options. Once it boots cleanly, merge the same settings into the audition runner.
- Keep log posts concise: start marker (`"[audition] script starting"`), before/after counts, per-SynthDef status. Enough to locate bottlenecks without spamming stdout.

