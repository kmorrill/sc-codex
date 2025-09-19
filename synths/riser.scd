SynthDef(\riser, {
    var freq = \freq.kr(220).clip(20, 8000);
    var amp = \amp.kr(0.28).clip(0, 0.35);
    var gate = \gate.kr(1);
    var riseTime = \riseTime.kr(4.2).clip(0.6, 14.0);
    var release = \release.kr(1.5).clip(0.2, 8.0);
    var startRatio = \startRatio.kr(0.15).clip(0.03, 1.0);
    var endRatio = \endRatio.kr(6.0).clip(2.5, 14.0);
    var filterRatio = \filterRatio.kr(3.2).clip(1.0, 8.0);
    var noiseMix = \noiseMix.kr(0.82).clip(0, 1);
    var cutoffCeiling = \cutoffCeiling.kr(14000).clip(2000, 18000);
    var pan = \pan.kr(0).clip(-1, 1);

    var ampEnv = Env.asr(0.05, 1.0, release, curve: -4).ar(gate: gate, doneAction: 2);
    var sweep = Env([freq * startRatio, freq * endRatio], [riseTime], 'exp').kr(gate: gate);
    var gateEnv = Env([0, 1, 0], [riseTime * 0.92, riseTime * 0.08], 'lin').kr(gate: gate);

    var osc = VarSaw.ar(sweep, width: 0.3, mul: 0.45);

    var noiseEnv = Env([0, 1, 0.8, 0], [riseTime * 0.55, riseTime * 0.35, release], curve: [-3, -3, -4]).ar(gate: gate);
    var air = HPF.ar(PinkNoise.ar(0.6), 600) * noiseEnv;
    var whoosh = BPF.ar(WhiteNoise.ar(0.5), sweep * (filterRatio * 0.5), 0.2) * noiseEnv;
    var roar = RLPF.ar(BrownNoise.ar(0.4), sweep * 0.9, 0.3) * noiseEnv;
    var hiss = HPF.ar(WhiteNoise.ar(0.35), 3800) * (noiseEnv * 0.7);

    var sig = osc * (1 - noiseMix) + (air + whoosh + roar + hiss) * noiseMix;
    var cutoff = (sweep * filterRatio).clip(200, cutoffCeiling);
    sig = RLPF.ar(sig, cutoff, 0.18);
    sig = sig * gateEnv;

    sig = LeakDC.ar(sig);
    sig = tanh(sig * 1.7) * ampEnv * amp;
    sig = Pan2.ar(sig, pan);
    Out.ar(\out.kr(0), sig);
}).add;
