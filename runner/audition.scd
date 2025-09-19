(
var s = Server.default;
s.options.device = nil;
s.options.sampleRate = 48000;
s.options.numInputBusChannels = 0;
s.options.numOutputBusChannels = 2;
s.options.inDevice = "MacBook Pro Microphone";
s.options.outDevice = "MacBook Pro Speakers";

"[audition] script starting".postln;

s.waitForBoot({
    var synthDir, synthFiles, descLib, before, newDefs;

    synthDir = (thisProcess.nowExecutingPath.dirname +/+ "../synths").standardizePath;
    ("Loading synths from: " ++ synthDir).postln;

    descLib = SynthDescLib.global;
    before = descLib.synthDescs.keys;
    ("SynthDefs before audition: " ++ before.size).postln;

    synthFiles = PathName(synthDir).entries.select({ |p|
        p.isFile and: { p.extension == "scd" }
    });

    synthFiles.sortBy(_.fileName).do({ |entry|
        ("Compiling " ++ entry.fileName).postln;
        try {
            this.compileFile(entry.fullPath);
        } {
            |err|
            ("   ⚠️ Compile failed for " ++ entry.fileName ++ ": " ++ err).postln;
        };
    });

    s.sync;

    newDefs = List.new;
    var after = descLib.synthDescs.keys;
    ("SynthDefs after audition load: " ++ after.size).postln;

    after.do({ |key|
        if(before.includes(key).not) {
            newDefs.add(key);
        };
    });
    newDefs = newDefs.asArray.sort;

    if(newDefs.isEmpty) {
        ("No SynthDefs loaded; installing fallback " ++ \bleep_demo.asString).postln;
        SynthDef(\bleep_demo, {
            var freq = \freq.kr(440).clip(20, 20000);
            var amp = \amp.kr(0.2).clip(0, 1);
            var env = Env.perc(0.01, 0.4, curve: -4).ar(doneAction: 2);
            var sig = SinOsc.ar(freq) * env * amp;
            Out.ar(\out.kr(0), sig ! 2);
        }).add;
        s.sync;
        newDefs = [\bleep_demo];
    };

    ("SynthDefs ready: " ++ newDefs.collect(_.asString).join(", ")).postln;

    {
        var clock = AppClock;
        var auditionNotes = [45, 60, 72, 84].midicps;
        var perNote = 0.25 + 0.05;
        var perDef = (auditionNotes.size * perNote) + 0.15;
        var timeoutSeconds = (newDefs.size * perDef + 1.0).max(6.0);
        var finished = false;

        var cleanup = { |timedOut|
            if(finished.not) {
                finished = true;
                if(timedOut) {
                    "⚠️ Audition timeout; forcing cleanup.".postln;
                } {
                    "Audition complete.".postln;
                };
                s.freeAll;
                s.quit;
                SystemClock.sched(0.1, {
                    0.exit;
                    nil;
                });
            };
        };

        SystemClock.sched(timeoutSeconds, {
            cleanup.value(true);
            nil;
        });

        Routine({
            newDefs.do({ |defName|
                ("Auditioning " ++ defName.asString).postln;
                auditionNotes.do({ |freq|
                    var synth;
                    try {
                        synth = Synth(defName, [\freq, freq, \amp, 0.2, \gate, 1]);
                    } {
                        |err|
                        ("   ⚠️ Could not start " ++ defName.asString ++ ": " ++ err).postln;
                        synth = nil;
                    };
                    0.25.wait;
                    if(synth.notNil) {
                        synth.set(\gate, 0);
                    };
                    0.05.wait;
                });
                0.15.wait;
            });
            0.2.wait;
            cleanup.value(false);
        }).play(clock);
    }.value;
});
).value;
