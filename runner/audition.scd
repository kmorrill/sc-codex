(
var s = Server.default;
s.options.device = nil;
s.options.sampleRate = 48000;
s.options.numInputBusChannels = 0;
s.options.numOutputBusChannels = 2;
s.options.inDevice = "MacBook Pro Microphone";
s.options.outDevice = "MacBook Pro Speakers";

"[audition] bass-only session starting".postln;

s.waitForBoot({
    var synthDir, synthFiles, bassDef;

    synthDir = (thisProcess.nowExecutingPath.dirname +/+ "../synths").standardizePath;
    synthFiles = PathName(synthDir).entries.select({ |p|
        p.isFile and: { p.extension == "scd" }
    }).sort({ |a, b| a.fileName < b.fileName });

    bassDef = nil;

    synthFiles.do({ |entry|
        ("Compiling " ++ entry.fileName).postln;
        try {
            thisProcess.interpreter.executeFile(entry.fullPath);
            if(entry.fileNameWithoutExtension == "bass_simple") {
                bassDef = \bass_simple;
            }
        } {
            |err|
            ("   ⚠️ Compile failed for " ++ entry.fileName ++ ": " ++ err).postln;
        };
    });

    s.sync;

    if(bassDef.isNil) {
        ("[audition] forcing fallback bass_simple").postln;
        SynthDef(\bass_simple, {
            var freq = \freq.kr(55).clip(20, 400);
            var amp = \amp.kr(0.2).clip(0, 0.3);
            var env = Env.perc(0.01, 0.4, curve: -4).ar(doneAction: 2);
            var sig = SinOsc.ar(freq) * env * amp;
            Out.ar(\out.kr(0), sig ! 2);
        }).add;
        s.sync;
        bassDef = \bass_simple;
    };

    ("SynthDef ready: " ++ bassDef.asString).postln;

    Routine({
        var notes = [33, 36, 38, 43, 36, 31, 28].midicps;
        notes.do({ |freq|
            ("Auditioning bass_simple @ " ++ freq.round(0.01)).postln;
            Synth(bassDef, [\freq, freq, \amp, 0.22]);
            0.8.wait;
        });
        0.4.wait;
        s.quit;
        SystemClock.sched(0.2, {
            0.exit;
            nil;
        });
    }).play(TempoClock.default);
});
)
