SynthDef(\soft_pad, {
    var freq = \freq.kr(220).clip(40, 8000);
    var amp = \amp.kr(0.18).clip(0, 0.3);
    var atk = \atk.kr(0.3).clip(0.01, 2.0);
    var rel = \rel.kr(2.5).clip(0.2, 8.0);
    var cutoff = \cutoff.kr(1800).clip(200, 10000);
    var res = \res.kr(0.25).clip(0.05, 0.9);
    var detune = \detune.kr(0.015).clip(0, 0.2);
    var vibRate = \vibRate.kr(0.35).clip(0.05, 5.0);
    var vibDepth = \vibDepth.kr(0.3).clip(0, 0.6);
    var pan = \pan.kr(0).clip(-1, 1);

    var env = Env.perc(atk, rel, curve: -4).ar(doneAction: 2);
    var vib = SinOsc.kr(vibRate).range(1 - vibDepth, 1 + vibDepth);
    var freqs = freq * vib * [1 - detune, 1 + detune];
    var saws = VarSaw.ar(freqs, width: 0.6, mul: 0.5).sum;
    var slowLfo = SinOsc.kr(0.12).range(0.5, 1.2);
    var body = RLPF.ar(saws, cutoff * slowLfo, res);
    var shimmer = BPF.ar(saws, cutoff * 1.8, 0.15, mul: 0.25);
    var sig = (body + shimmer) * env * amp;
    sig = tanh(sig * 1.3);
    sig = Pan2.ar(sig, pan);
    Out.ar(\out.kr(0), sig);
}).add;
"[soft_pad loaded]".postln;
