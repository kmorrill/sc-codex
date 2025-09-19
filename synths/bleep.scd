SynthDef(\bleep, {
    var freq = \freq.kr(440).clip(20, 20000);
    var amp = \amp.kr(0.2).clip(0, 0.3);
    var atk = \atk.kr(0.01).clip(0.001, 1.0);
    var rel = \rel.kr(0.3).clip(0.01, 4.0);
    var cutoff = \cutoff.kr(5000).clip(100, 20000);
    var env = Env.perc(atk, rel, curve: -4).ar(doneAction: 2);
    var sig = Saw.ar(freq * [0.99, 1.01]).sum * 0.5;
    sig = LPF.ar(sig, cutoff);
    sig = sig * env * amp;
    Out.ar(\out.kr(0), sig ! 2);
}).add;
