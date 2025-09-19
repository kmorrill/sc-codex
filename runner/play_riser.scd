(
var s = Server.default;
s.options.device = nil;
s.options.sampleRate = 48000;
s.options.numInputBusChannels = 0;
s.options.numOutputBusChannels = 2;
s.options.inDevice = "MacBook Pro Microphone";
s.options.outDevice = "MacBook Pro Speakers";

"[riser] starting single audition".postln;

s.waitForBoot({
    var synthPath = (thisProcess.nowExecutingPath.dirname +/+ "../synths/riser.scd").standardizePath;
    thisProcess.interpreter.executeFile(synthPath);
    s.sync;

    Routine({
        var synth;
        synth = Synth(\riser, [
            \amp, 0.3,
            \riseTime, 6.5,
            \endRatio, 6.5,
            \noiseMix, 0.85,
            \filterRatio, 3.4,
            \cutoffCeiling, 15000
        ]);
        8.5.wait;
        synth.set(\gate, 0);
        1.wait;
        "[riser] done".postln;
        s.quit;
        0.exit;
    }).play(AppClock);
});
)
