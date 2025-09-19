SCLANG := /Applications/SuperCollider.app/Contents/MacOS/sclang
SCSYNTH := /Applications/SuperCollider.app/Contents/Resources/scsynth

AUDITION_SCRIPT := $(abspath runner/audition.scd)
AUDIO_CONF := $(abspath runner/sclang_conf.yaml)
AUDIO_RUNTIME := $(abspath runner/runtime)
AUDITION_WRAPPER := $(abspath runner/run_audition.py)
PYTHON ?= python3

.PHONY: audition boot watch

audition:
	$(PYTHON) $(AUDITION_WRAPPER)

.PHONY: audition-debug

audition-debug:
	AUDITION_DEBUG=1 $(PYTHON) $(AUDITION_WRAPPER)

boot:
	$(SCSYNTH) -u 57110

watch:
	@ls synths/*.scd 2>/dev/null | entr -r make audition
