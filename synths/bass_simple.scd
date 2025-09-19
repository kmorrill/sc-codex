SynthDef(\bass_simple, {
    var freq = \freq.kr(55).clip(20, 400);
    var amp = \amp.kr(0.18).clip(0, 0.3);
    var atk = \atk.kr(0.005).clip(0.001, 0.2);
    var rel = \rel.kr(0.25).clip(0.01, 2.0);
    var glide = \glide.kr(0.02).clip(0.0, 1.0);
    var cutoff = \cutoff.kr(800).clip(40, 4000);
    var wobbleRate = \wobble_rate.kr(3).clip(0.1, 12);
    var wobbleDepth = \wobble_depth.kr(0.35).clip(0, 1);
    var grit = \grit.kr(0.7).clip(0, 2);
    var gate = \gate.kr(1);
    var env = Env.adsr(atk, 0.08, 0.5, rel, curve: -6).ar(gate: gate, doneAction: 2);
    var pitch = Lag.kr(freq, glide);
    var wobble = SinOsc.kr(wobbleRate, 0).linlin(-1, 1, 0.3.neg, 0.3) + LFNoise1.kr(wobbleRate * 1.7, 0.2);
    var cutoffMod = (cutoff * (1 + wobbleDepth * wobble)).clip(80, 5000);
    var main = Mix([
        VarSaw.ar(pitch, 0, 0.3),
        Pulse.ar(pitch, 0.4)
    ]) * 0.4;
    var sub = SinOsc.ar(pitch * 0.5) * 0.5;
    var dirt = (main + sub) + BPF.ar(WhiteNoise.ar(0.08), cutoffMod, 0.3);
    var filtered = RLPF.ar(dirt, cutoffMod, 0.35);
    var driven = tanh((filtered * (1.2 + grit)) + (filtered.squared * 0.4));
    var body = LeakDC.ar(driven);
    var sig = (body * env * amp).tanh;
    Out.ar(\out.kr(0), sig ! 2);
}).add;
"[bass_simple loaded]".postln;
