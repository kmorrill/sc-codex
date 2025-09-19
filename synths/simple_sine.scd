SynthDef(\simple_sine, {
    var freq = \freq.kr(55).clip(20, 400);
    var amp = \amp.kr(0.2).clip(0, 0.3);
    var env = Env.perc(0.01, 0.4, curve: -4).ar(doneAction: 2);
    var sig = SinOsc.ar(freq) * env * amp;
    Out.ar(\out.kr(0), sig ! 2);
}).add;
"[simple_sine loaded]".postln;
