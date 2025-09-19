SCLANG := /Applications/SuperCollider.app/Contents/MacOS/sclang
SCSYNTH := /Applications/SuperCollider.app/Contents/Resources/scsynth

AUDITION_SCRIPT := $(abspath runner/audition.scd)
AUDIO_CONF := $(abspath runner/sclang_conf.yaml)
AUDIO_RUNTIME := $(abspath runner/runtime)

.PHONY: audition boot watch

audition:
	SC_AUDITION=1 $(SCLANG) -d $(AUDIO_RUNTIME) -l $(AUDIO_CONF) $(AUDITION_SCRIPT)

boot:
	$(SCSYNTH) -u 57110

watch:
	@ls synths/*.scd 2>/dev/null | entr -r make audition
