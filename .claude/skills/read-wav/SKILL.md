---
name: read-wav
description: Record Mednafen's audio output to a WAV and verify it numerically, covering the -soundrecord launch pattern, the analyze:wav report (per-channel levels, silence, dominant frequencies), and how to turn a test ROM's audible pass criterion into checkable numbers before a hardware test. Use when an agent needs to confirm a VSU test ROM plays the tone it claims, compare left/right loudness, diagnose a silent or wrong-pitch channel under a reference emulator, or read any WAV file's contents without ears.
---

# Read WAV

An agent cannot hear. This skill turns "listen and judge" into numbers: record Mednafen's audio to a WAV, then read the WAV back as levels and frequencies. A tone criterion like "440 Hz, louder on the right" becomes two checkable lines instead of a request for someone's ears.

The scope caveat comes first: a recording verifies the ROM against Mednafen's VSU, not against ours. It is the audio equivalent of the header check in the `build-test-rom` skill — it catches a wrong ROM before it wastes a hardware test, and it says nothing about the core. The Pocket listen is still the verdict.

## Record

Mednafen's `-soundrecord <file>` writes its audio output as 16-bit PCM WAV. It composes with the headless launch pattern from `build-test-rom`; the recording covers the whole run, so the sleep sets its length.

```powershell
$med  = 'C:\Users\morgan\Documents\Emulators\mednafen-1.32.1-win64\mednafen.exe'
$base = Split-Path $med
$wav  = '<absolute path>\vsu-tone.wav'
$rom  = '<repo>\.roms\vsu-tone.vb'
Remove-Item "$base\stdout.txt", $wav -ErrorAction SilentlyContinue
$proc = Start-Process $med -ArgumentList '-soundrecord', "`"$wav`"", "`"$rom`"" -WorkingDirectory $base -PassThru
Start-Sleep -Seconds 8
Stop-Process -Id $proc.Id -Force
```

Two things bite here:

- **The WAV path must be absolute.** Mednafen resolves a relative one against its own base directory, next to `stdout.txt`.
- **Killing the process leaves the WAV header unpatched.** The RIFF and data size fields stay zero because Mednafen never got to close the file. The analyzer tolerates this and reads samples to end of file; a stricter WAV tool may refuse the same recording.

## Analyze

```bash
pnpm run analyze:wav <file.wav>
```

The script is `scripts/analyze-wav.ts`. For each channel it reports overall peak and RMS in dBFS, then the dominant frequencies of the loudest stretch of the recording — the FFT window is placed over the highest-energy region, so leading boot silence does not dilute the reading. A real run of `vsu-tone` looks like:

```
vsu-tone.wav  48000 Hz  2 channel(s)  7.68s
left   peak -20.7 dBFS  rms -26.8 dBFS  window 1.37s at 0.00s
          110.0 Hz     0.0 dB
          330.1 Hz    -9.7 dB
          550.2 Hz   -13.8 dB
right  peak -9.6 dBFS  rms -15.6 dBFS  window 1.37s at 0.00s
          110.0 Hz     0.0 dB
          330.1 Hz    -9.7 dB
```

How to read it:

- **Frequency peaks are relative to the strongest, which sits at 0.0 dB.** The first line of each list is the dominant pitch. Peaks more than 40 dB down are dropped.
- **A square wave shows as a fundamental plus odd harmonics** (f, 3f, 5f…) at falling levels, as above. A pure sine shows one peak. A chord shows one peak per note.
- **Loudness comparisons use peak/RMS dBFS.** In the example the right channel is ~11 dB louder, which is what an `SxLRV` of left 4, right 15 should produce.
- **`silent` means RMS under -60 dBFS.** That is the "silence means the audio path failed" arm of an expectation.

## Check against the expectation, not against vibes

Work out the frequency the ROM should produce before recording, from its register writes. For a VSU wave channel, Mednafen's implementation gives

```
f = 5,000,000 / ((2048 - FRQ) * 32)   Hz, FRQ = SxFQH:SxFQL
```

verified empirically: `vsu-tone` writes `FRQ = 0x274` (628) and records at 110.0 Hz exactly. The `* 32` is the wavetable length, so this is the pitch of one full table sweep.

If the recorded fundamental disagrees with the ROM's `expectation`, say so rather than picking one quietly — either the expectation was written wrong or the register math was, and both look identical on hardware.

## Not just Mednafen

`analyze:wav` reads any 16-bit PCM WAV. A testbench that dumps samples, a capture from the Pocket's line out, or a reference recording all go through the same report, which makes "does the core's output match Mednafen's" a diff of two short tables.
