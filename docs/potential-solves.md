# Research on unsolved challenges in the audition‑runner project

The repository includes a small SuperCollider‑based audition system that compiles and runs SynthDefs on a local sclang server. The provided unsolved‑challenges.md file lists several pain points encountered while automating this process. In this report each challenge is summarised and potential solutions are proposed based on SuperCollider documentation and community discussions.

## 1 Runner sometimes halts at the sc3\> prompt

### Problem

When the agent runs sclang to audition a SynthDef, the process occasionally boots, prints the banner and stops at the sc3\> prompt instead of running the supplied code. The automation expects sclang to immediately evaluate a code block and exit, so any pause at the REPL blocks the pipeline.

### Research

SuperCollider’s command‑line interpreter supports a **daemon mode**. According to the sclang manual, the \-D flag “enter(s) daemon mode (no input)”[\[1\]](https://manpages.debian.org/testing/supercollider-language/sclang.1.en.html#:~:text=,default%20256k). In daemon mode sclang does not wait for interactive input and therefore never presents the sc3\> prompt. It is also possible to make sclang call a method at startup by using the \-r option, which triggers Main.run when booting[\[2\]](https://manpages.debian.org/testing/supercollider-language/sclang.1.en.html#:~:text=,stop%20on%20shutdown); the \-s flag calls Main.stop on shutdown. Community posts on the SuperCollider forum confirm that running sclang with the \-D flag allows headless use of the interpreter and that remote evaluation can then be done via OSC messages[\[3\]](https://scsynth.org/t/6501.json#:~:text=initialise,09). The same threads suggest sending code to sclang through OSC or through a wrapper script rather than writing to the REPL, because the REPL may wait for a newline or hang.

Another approach is to avoid using stdin and instead **run sclang with a script file**. If a .scd file is provided as an argument, sclang will load the file, evaluate its contents and then exit when 0.exit is called. Using sclang \-D with \-r and \-s allows headless operation and ensures the script runs through Main.run.

### Potential solutions

* **Run sclang in daemon mode**. Start sclang with the \-D flag to disable stdin and never present the sc3\> prompt[\[1\]](https://manpages.debian.org/testing/supercollider-language/sclang.1.en.html#:~:text=,default%20256k). Combine this with \-r to call Main.run automatically on startup; the audition code can call Main.stop or send 0.exit when complete.

* **Send code through a script file rather than stdin**. Generate a temporary .scd file containing the audition block, then run sclang \-D \-r \<file.scd\>. This avoids interactive REPL behaviour and ensures one clean EOF.

* **Use OSC for remote evaluation**. In daemon mode sclang opens an OSC port (default 57120). The Python harness can send the audition code via OSC /evaluate messages. This eliminates reliance on the REPL and avoids halting at sc3\>[\[3\]](https://scsynth.org/t/6501.json#:~:text=initialise,09).

## 2 SynthDef discovery is inconsistent

### Problem

The audition runner monitors SynthDescLib.global.synthDescs.keys before and after loading a SynthDef to determine whether the definition was successfully registered. In some runs the difference set doesn’t include the actual SynthDef (for example \\bleep), causing the runner to install a fallback definition. The problem arises because SynthDef registration happens asynchronously, and reading the key list immediately after sending the definition may yield stale data.

### Research

The SynthDef class provides .store and .add methods. Both add the SynthDef to SynthDescLib and send it to all registered servers[\[4\]](https://doc.sccode.org/Classes/SynthDef.html#:~:text=Adds%20the%20synthdef%20to%20the,operations%20take%20place%20in%20memory). Importantly, calling .add triggers **an update message** with the key \\synthDescAdded for any dependants registered with SynthDescLib[\[5\]](https://doc.sccode.org/Classes/SynthDef.html#:~:text=Adds%20the%20synthdef%20to%20the,operations%20take%20place%20in%20memory). The documentation for SynthDescLib:add reiterates that adding a SynthDesc triggers the same \\synthDescAdded update for dependants[\[6\]](https://doc.sccode.org/Classes/SynthDescLib.html#:~:text=). In other words, the recommended way to detect newly registered SynthDefs is to attach a dependant to the library, listen for the \\synthDescAdded update and act when it occurs.

Additionally, SynthDescLib.read can be used to load compiled synthdef files from disk[\[7\]](https://doc.sccode.org/Classes/SynthDesc.html#:~:text=SynthDescs%20are%20needed%20by%20the,are%20derived%20from%20the%20SynthDesc). However, this method is not automatically called on startup; forum posts note that one must explicitly call SynthDescLib.read or rely on .add in code[\[8\]](https://scsynth.org/t/1139.json).

### Potential solutions

* **Avoid key‑diff polling**. Instead of computing the difference between SynthDescLib.global.synthDescs.keys before and after loading, register the audition script as a dependant of SynthDescLib.global. When a SynthDef is added, SuperCollider will send a \\synthDescAdded notification to dependants[\[4\]](https://doc.sccode.org/Classes/SynthDef.html#:~:text=Adds%20the%20synthdef%20to%20the,operations%20take%20place%20in%20memory). The automation can then update its internal list of synthdefs.

* **Wait for asynchronous completion**. Use .store or .send with a completion message that triggers evaluation only once the server has received the SynthDef. For example, SynthDef(name, {...}).store(nil, { /\* call audition code here \*/ }); ensures the code runs after the registration completes.

* **Fallback based on existence checks**. After loading a SynthDef, call SynthDescLib.global.at(\\bleep); if it returns nil, treat it as missing. This is more reliable than key diffs because it queries the actual library entry.

* **Ensure startup loads known synthdefs**. If synthdefs are stored on disk, call SynthDescLib.global.read at startup to preload them[\[7\]](https://doc.sccode.org/Classes/SynthDesc.html#:~:text=SynthDescs%20are%20needed%20by%20the,are%20derived%20from%20the%20SynthDesc).

## 3 Audio device selection drift

### Problem

On macOS the server sometimes boots using AirPods or another Bluetooth device with a 24 kHz input, causing a sample‑rate mismatch (input 44.1 kHz vs output 48 kHz). This leads to boot failures. The runner attempts to force the MacBook’s built‑in speaker and microphone, but macOS occasionally reverts to AirPods.

### Research

SuperCollider’s ServerOptions provide explicit control over input and output devices. The Audio Device Selection documentation shows that one can set both input and output devices using Server.default.options.inDevice\_("Built‑in Microph") and Server.default.options.outDevice\_("Built‑in Output")[\[9\]](https://doc.sccode.org/Reference/AudioDeviceSelection.html#:~:text=macOS). Alternatively, one can set a single device string (e.g., "MOTU 828") to use an aggregate device[\[10\]](https://doc.sccode.org/Reference/AudioDeviceSelection.html#:~:text=Server.default.options.device_%28). The documentation notes that **sample‑rate mismatches between input and output devices are a common cause of boot failures**[\[11\]](https://doc.sccode.org/Reference/AudioDeviceSelection.html#:~:text=Sample%20rate%20mismatch) and advises ensuring both devices operate at the same sample rate through Audio MIDI Setup[\[12\]](https://doc.sccode.org/Reference/AudioDeviceSelection.html#:~:text=You%20should%20set%20both%20input,this%20in%20Audio%20MIDI%20Setup). Mac users can also create an **aggregate device** by combining multiple physical devices in the Audio MIDI Setup; SuperCollider can then target that aggregate device by name[\[13\]](https://doc.sccode.org/Reference/AudioDeviceSelection.html#:~:text=Aggregate%20device).

During server boot, the list of available devices can be queried without booting using ServerOptions.devices, ServerOptions.inDevices and ServerOptions.outDevices[\[14\]](https://doc.sccode.org/Reference/AudioDeviceSelection.html#:~:text=On%20Windows%20and%20macOS%20you,devices%20without%20booting%20the%20server). On macOS, it may also be necessary to set the input channel count to zero for output‑only servers or to explicitly set the sample rate to 48 kHz.

### Potential solutions

* **Explicitly set the input and output devices at runtime.** Before booting, call o \= Server.default.options; o.inDevice\_("Built‑in Microph"); o.outDevice\_("Built‑in Output");[\[9\]](https://doc.sccode.org/Reference/AudioDeviceSelection.html#:~:text=macOS). This ensures sclang uses the built‑in hardware even if the system default points elsewhere.

* **Disable inputs if only output is needed.** Set Server.default.options.numInputBusChannels \= 0 to avoid attaching an input device. This prevents AirPods from being selected as an input and solves sample‑rate mismatch errors.

* **Match sample rates.** Use Audio MIDI Setup to set both devices to the same sample rate (usually 48 kHz) and configure Server.default.options.sampleRate \= 48000 in the audition script. The documentation notes that mismatched sample rates are a common failure source[\[15\]](https://doc.sccode.org/Reference/AudioDeviceSelection.html#:~:text=Sample%20rate%20mismatch).

* **Use an aggregate device.** If you must use Bluetooth headphones for output and the internal microphone for input, create an aggregate device in Audio MIDI Setup and set Server.default.options.device \= "Aggregate Device"[\[13\]](https://doc.sccode.org/Reference/AudioDeviceSelection.html#:~:text=Aggregate%20device). This unifies sample rates and channels.

## 4 Plugin dependencies (MiPlaits, MiRings, MiClouds and SuperDirt)

### Problem

Several audition scripts reference Mutable Instruments UGens (e.g., MiPlaits, MiRings, MiClouds) and SuperDirt classes. When these plugins are not installed, sclang posts warnings (“UGen not installed”) and the scripts fail.

### Research

The Mutable Instruments UGens are not part of the SuperCollider core. They are provided by the **mi‑UGens** package. The TidalCycles documentation explains that to install them manually, one should download the latest release from the mi‑UGens GitHub repository and **unpack the mi‑UGens/ directory into the SuperCollider Extensions folder**[\[16\]](https://tidalcycles.org/docs/reference/mi-ugens-installation/#:~:text=1,appropriate%20to%20your%20Operating%20System). The correct location varies by platform (e.g., \~/Library/Application Support/SuperCollider/Extensions/mi‑UGens on macOS)[\[17\]](https://tidalcycles.org/docs/reference/mi-ugens-installation/#:~:text=%2A%20Linux%3A%20%60%2Fhome%2F%3Cyouruser%3E%2F.local%2Fshare%2FSuperCollider%2FExtensions%2Fmi,UGens). After installation, one may need to load the provided synthdef file or add initialization code in startup.scd[\[18\]](https://tidalcycles.org/docs/reference/mi-ugens-installation/#:~:text=post%20window). On macOS the operating system may block unsigned binaries; the docs note that users may need to override security settings or use a workaround[\[19\]](https://tidalcycles.org/docs/reference/mi-ugens-installation/#:~:text=OSX%20Users%21,post%20by%20%40oscd%20for%20workarounds%2Ffixes).

SuperCollider’s **sc3‑plugins** repository contains a broader collection of community UGens. The official release page advises to download the release archive, unzip it and move the resulting SC3plugins folder into the SuperCollider Extensions directory[\[20\]](https://supercollider.github.io/sc3-plugins/#:~:text=Installation). If pre‑compiled binaries are unavailable or incompatible (e.g., M1 Macs), the plugins can be built from source by cloning supercollider and sc3‑plugins and running cmake to build and install them[\[21\]](https://supercollider.github.io/sc3-plugins/#:~:text=Compile%20from%20source). Building requires the SuperCollider sources and may need additional flags; see the documentation for details[\[22\]](https://supercollider.github.io/sc3-plugins/#:~:text=Compile%20from%20source).

### Potential solutions

* **Bundle precompiled plugins.** Download the latest mi‑UGens and sc3‑plugins releases for the target operating system and include them in the audition runner’s Docker image. Place them in the Extensions folder (the path returned by Platform.userExtensionDir)[\[16\]](https://tidalcycles.org/docs/reference/mi-ugens-installation/#:~:text=1,appropriate%20to%20your%20Operating%20System)[\[20\]](https://supercollider.github.io/sc3-plugins/#:~:text=Installation). After installation, recompile the SuperCollider class library.

* **Automate plugin installation in the runner.** On first run, detect missing UGens by catching “UGen not installed” warnings. If missing, attempt to fetch the release archive from GitHub and extract to the Extensions path. Then call Platform.recompile or instruct the user to restart the server.

* **Provide fallback SynthDefs.** For environments where plugin installation is impossible, supply simplified fallback SynthDefs that use core UGens (e.g., Saw, Sine, Noise) instead of MiPlaits or MiRings. The fallback can be selected based on whether the UGen exists: check SynthDescLib.global.at(\\MiPlaits).notNil before deciding which def to use.

* **Support building from source.** Document the build process: clone sc3‑plugins and SuperCollider, run cmake -DSC\_PATH=\<path\> .. followed by cmake --build . --target install[\[21\]](https://supercollider.github.io/sc3-plugins/#:~:text=Compile%20from%20source). This is necessary for architectures without pre‑built binaries (e.g., Apple Silicon). The runner could optionally perform this compilation in a container.

## 5 Headless exit noise (“Exiting sclang (ctrl‑D)” spam)

### Problem

Feeding code into sclang via stdin results in thousands of lines like Exiting sclang (ctrl‑D) being printed to the log. This noise obscures real errors and slows down log parsing.

### Research

The repeated messages are triggered because multiple end‑of‑file signals are being sent to sclang. When sclang receives an EOF (e.g., via Ctrl‑D), it posts “Exiting sclang (ctrl‑D)” before quitting. In the Python–SuperCollider integration thread, logs show these messages repeated hundreds of times[\[23\]](https://scsynth.org/t/3793.json#:~:text=When%20I%20run%20the%20code%2C,D%29%5Cnsc3%5Cu0026gt%3B%5Cn%5Cu003c%2Fcode%5Cu003e%5Cu003c%2Fpre%5Cu003e%22%2C%22post_number%22%3A7%2C%22post_type), indicating that the wrapper is sending more than one EOF. Running sclang in **daemon mode** (\-D) suppresses stdin entirely and thereby prevents these messages[\[1\]](https://manpages.debian.org/testing/supercollider-language/sclang.1.en.html#:~:text=,default%20256k). Using a script file rather than piping input also avoids sending multiple EOFs.

### Potential solutions

* **Stop using stdin.** Switch to sclang -D and send code via OSC or a temporary script file. Without stdin, sclang never sees an EOF and therefore never prints “Exiting sclang (ctrl‑D).”

* **Ensure only one EOF.** If stdin must be used, write the audition block followed by a single Ctrl‑D and avoid sending further input. The repeated messages arise when the wrapper writes newlines after sclang has already shut down.

* **Filter or discard exit messages.** As a fallback, the runner can filter the process output and discard lines matching the exit message before logging, but eliminating the cause (using daemon mode) is preferable.

## Recommendations for the automation agent

1. **Adopt daemon mode by default.** Invoke sclang with \-D -r and run a script file containing the audition code. Use OSC messages for dynamic evaluation. This prevents interactive prompts and eliminates exit‑noise spam[\[1\]](https://manpages.debian.org/testing/supercollider-language/sclang.1.en.html#:~:text=,default%20256k)[\[3\]](https://scsynth.org/t/6501.json#:~:text=initialise,09).

2. **Replace key‑diff logic with dependable events.** Attach a dependant to SynthDescLib.global and listen for the \\synthDescAdded update[\[4\]](https://doc.sccode.org/Classes/SynthDef.html#:~:text=Adds%20the%20synthdef%20to%20the,operations%20take%20place%20in%20memory)[\[6\]](https://doc.sccode.org/Classes/SynthDescLib.html#:~:text=). Use the update callback to register new SynthDefs and avoid race conditions.

3. **Enforce audio devices and sample rate.** Before booting the server, set inDevice\_, outDevice\_ and sampleRate explicitly[\[9\]](https://doc.sccode.org/Reference/AudioDeviceSelection.html#:~:text=macOS)[\[15\]](https://doc.sccode.org/Reference/AudioDeviceSelection.html#:~:text=Sample%20rate%20mismatch). Consider disabling inputs or using an aggregate device if necessary. Boot the server only after verifying the desired devices are available via ServerOptions.devices[\[14\]](https://doc.sccode.org/Reference/AudioDeviceSelection.html#:~:text=On%20Windows%20and%20macOS%20you,devices%20without%20booting%20the%20server).

4. **Package required plugins and provide fallbacks.** Bundle mi‑UGens and sc3‑plugins or automate their installation from GitHub releases[\[16\]](https://tidalcycles.org/docs/reference/mi-ugens-installation/#:~:text=1,appropriate%20to%20your%20Operating%20System)[\[20\]](https://supercollider.github.io/sc3-plugins/#:~:text=Installation). Provide fallback SynthDefs that do not depend on external UGens.

5. **Simplify exit handling.** When the audition finishes, call 0.exit or Main.stop once. Avoid sending additional data to stdin after the process has exited to prevent repeated exit messages.

By applying these measures the audition runner should become more robust and less susceptible to hanging at prompts, missing SynthDefs, device misconfiguration, plugin errors and exit‑noise spam.

---

[\[1\]](https://manpages.debian.org/testing/supercollider-language/sclang.1.en.html#:~:text=,default%20256k) [\[2\]](https://manpages.debian.org/testing/supercollider-language/sclang.1.en.html#:~:text=,stop%20on%20shutdown) sclang(1) — supercollider-language — Debian testing — Debian Manpages

[https://manpages.debian.org/testing/supercollider-language/sclang.1.en.html](https://manpages.debian.org/testing/supercollider-language/sclang.1.en.html)

[\[3\]](https://scsynth.org/t/6501.json#:~:text=initialise,09) scsynth.org

[https://scsynth.org/t/6501.json](https://scsynth.org/t/6501.json)

[\[4\]](https://doc.sccode.org/Classes/SynthDef.html#:~:text=Adds%20the%20synthdef%20to%20the,operations%20take%20place%20in%20memory) [\[5\]](https://doc.sccode.org/Classes/SynthDef.html#:~:text=Adds%20the%20synthdef%20to%20the,operations%20take%20place%20in%20memory) SynthDef | SuperCollider 3.14.0 Help

[https://doc.sccode.org/Classes/SynthDef.html](https://doc.sccode.org/Classes/SynthDef.html)

[\[6\]](https://doc.sccode.org/Classes/SynthDescLib.html#:~:text=) SynthDescLib | SuperCollider 3.14.0 Help

[https://doc.sccode.org/Classes/SynthDescLib.html](https://doc.sccode.org/Classes/SynthDescLib.html)

[\[7\]](https://doc.sccode.org/Classes/SynthDesc.html#:~:text=SynthDescs%20are%20needed%20by%20the,are%20derived%20from%20the%20SynthDesc) SynthDesc | SuperCollider 3.14.0 Help

[https://doc.sccode.org/Classes/SynthDesc.html](https://doc.sccode.org/Classes/SynthDesc.html)

[\[8\]](https://scsynth.org/t/1139.json) scsynth.org

[https://scsynth.org/t/1139.json](https://scsynth.org/t/1139.json)

[\[9\]](https://doc.sccode.org/Reference/AudioDeviceSelection.html#:~:text=macOS) [\[10\]](https://doc.sccode.org/Reference/AudioDeviceSelection.html#:~:text=Server.default.options.device_%28) [\[11\]](https://doc.sccode.org/Reference/AudioDeviceSelection.html#:~:text=Sample%20rate%20mismatch) [\[12\]](https://doc.sccode.org/Reference/AudioDeviceSelection.html#:~:text=You%20should%20set%20both%20input,this%20in%20Audio%20MIDI%20Setup) [\[13\]](https://doc.sccode.org/Reference/AudioDeviceSelection.html#:~:text=Aggregate%20device) [\[14\]](https://doc.sccode.org/Reference/AudioDeviceSelection.html#:~:text=On%20Windows%20and%20macOS%20you,devices%20without%20booting%20the%20server) [\[15\]](https://doc.sccode.org/Reference/AudioDeviceSelection.html#:~:text=Sample%20rate%20mismatch) Audio device selection | SuperCollider 3.14.0 Help

[https://doc.sccode.org/Reference/AudioDeviceSelection.html](https://doc.sccode.org/Reference/AudioDeviceSelection.html)

[\[16\]](https://tidalcycles.org/docs/reference/mi-ugens-installation/#:~:text=1,appropriate%20to%20your%20Operating%20System) [\[17\]](https://tidalcycles.org/docs/reference/mi-ugens-installation/#:~:text=%2A%20Linux%3A%20%60%2Fhome%2F%3Cyouruser%3E%2F.local%2Fshare%2FSuperCollider%2FExtensions%2Fmi,UGens) [\[18\]](https://tidalcycles.org/docs/reference/mi-ugens-installation/#:~:text=post%20window) [\[19\]](https://tidalcycles.org/docs/reference/mi-ugens-installation/#:~:text=OSX%20Users%21,post%20by%20%40oscd%20for%20workarounds%2Ffixes) mi-UGens Installation | Tidal Cycles

[https://tidalcycles.org/docs/reference/mi-ugens-installation/](https://tidalcycles.org/docs/reference/mi-ugens-installation/)

[\[20\]](https://supercollider.github.io/sc3-plugins/#:~:text=Installation) [\[21\]](https://supercollider.github.io/sc3-plugins/#:~:text=Compile%20from%20source) [\[22\]](https://supercollider.github.io/sc3-plugins/#:~:text=Compile%20from%20source) Releases | sc3-plugins

[https://supercollider.github.io/sc3-plugins/](https://supercollider.github.io/sc3-plugins/)

[\[23\]](https://scsynth.org/t/3793.json#:~:text=When%20I%20run%20the%20code%2C,D%29%5Cnsc3%5Cu0026gt%3B%5Cn%5Cu003c%2Fcode%5Cu003e%5Cu003c%2Fpre%5Cu003e%22%2C%22post_number%22%3A7%2C%22post_type) scsynth.org

[https://scsynth.org/t/3793.json](https://scsynth.org/t/3793.json)