(
var s = Server.default;
s.options.device = nil;
s.options.sampleRate = 48000;
s.options.numInputBusChannels = 0;
s.options.numOutputBusChannels = 2;
s.options.inDevice = "MacBook Pro Microphone";
s.options.outDevice = "MacBook Pro Speakers";

"[audition] simple session starting".postln;

s.waitForBoot({
    var synthDir, synthFiles, loaded;

    synthDir = (thisProcess.nowExecutingPath.dirname +/+ "../synths").standardizePath;
    synthFiles = PathName(synthDir).entries.select({ |p|
        p.isFile and: { p.extension == "scd" }
    }).sort({ |a, b| a.fileName < b.fileName });

    loaded = List.new;

    synthFiles.do({ |entry|
        ("Compiling " ++ entry.fileName).postln;
        try {
            thisProcess.interpreter.executeFile(entry.fullPath);
            loaded.add(entry.fileNameWithoutExtension.asSymbol);
        } {
            |err|
            ("   ⚠️ Compile failed for " ++ entry.fileName ++ ": " ++ err).postln;
        };
    });

    s.sync;

    if(loaded.isEmpty) {
        ("No SynthDefs loaded; installing fallback simple_sine").postln;
        SynthDef(\simple_sine, {
            var freq = \freq.kr(55).clip(20, 400);
            var amp = \amp.kr(0.2).clip(0, 0.3);
            var env = Env.perc(0.01, 0.4, curve: -4).ar(doneAction: 2);
            var sig = SinOsc.ar(freq) * env * amp;
            Out.ar(\out.kr(0), sig ! 2);
        }).add;
        s.sync;
        loaded = [\simple_sine];
    };

    ("SynthDefs ready: " ++ loaded.collect(_.asString).join(", ")).postln;

    Routine({
        var clock = TempoClock.default;
        loaded.do({ |defName|
            ("Auditioning " ++ defName.asString).postln;
            Synth(defName, [\freq, 55, \amp, 0.2]);
            0.6.wait;
        });
        0.3.wait;
        s.quit;
        SystemClock.sched(0.2, {
            0.exit;
            nil;
        });
    }).play(TempoClock.default);
});
)
