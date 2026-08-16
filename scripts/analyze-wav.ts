#!/usr/bin/env node

import * as NodeRuntime from "@effect/platform-node/NodeRuntime";
import * as NodeServices from "@effect/platform-node/NodeServices";
import * as Console from "effect/Console";
import * as Effect from "effect/Effect";
import * as FileSystem from "effect/FileSystem";
import * as Schema from "effect/Schema";
import { Argument, Command } from "effect/unstable/cli";

export class WavReadError extends Schema.TaggedErrorClass<WavReadError>()("WavReadError", {
  path: Schema.String,
  cause: Schema.Defect(),
}) {
  override get message(): string {
    return `Reading ${this.path} failed.`;
  }
}

export class WavParseError extends Schema.TaggedErrorClass<WavParseError>()("WavParseError", {
  path: Schema.String,
  cause: Schema.Defect(),
}) {
  override get message(): string {
    return `${this.path} is not a readable WAV file.`;
  }
}

export interface WavAudio {
  readonly sampleRate: number;
  /** One Float64Array per channel, samples in -1..1. */
  readonly channels: ReadonlyArray<Float64Array>;
}

/**
 * Parses a RIFF WAV file holding 16-bit PCM, the format Mednafen's
 * -soundrecord writes. A recording stopped by killing the process never gets
 * its size fields patched, so a zero or overlong data size means "to end of
 * file" rather than an error.
 */
export const parseWav = (bytes: Uint8Array): WavAudio => {
  const view = new DataView(bytes.buffer, bytes.byteOffset, bytes.byteLength);
  const tag = (offset: number) => String.fromCharCode(...bytes.subarray(offset, offset + 4));
  if (bytes.length < 44 || tag(0) !== "RIFF" || tag(8) !== "WAVE") {
    throw new Error("missing RIFF/WAVE header");
  }

  let format:
    | { audioFormat: number; channelCount: number; sampleRate: number; bitsPerSample: number }
    | undefined;
  let data: Uint8Array | undefined;
  let offset = 12;
  while (offset + 8 <= bytes.length) {
    const id = tag(offset);
    const declaredSize = view.getUint32(offset + 4, true);
    const body = offset + 8;
    if (id === "fmt " && body + 16 <= bytes.length) {
      format = {
        audioFormat: view.getUint16(body, true),
        channelCount: view.getUint16(body + 2, true),
        sampleRate: view.getUint32(body + 4, true),
        bitsPerSample: view.getUint16(body + 14, true),
      };
    } else if (id === "data") {
      const end = declaredSize === 0 ? bytes.length : Math.min(body + declaredSize, bytes.length);
      data = bytes.subarray(body, end);
      if (declaredSize === 0) break;
    }
    offset = body + declaredSize + (declaredSize & 1);
  }

  if (format === undefined || data === undefined) throw new Error("missing fmt or data chunk");
  if (format.audioFormat !== 1 || format.bitsPerSample !== 16) {
    throw new Error(
      `only 16-bit PCM is supported, got format ${format.audioFormat} at ${format.bitsPerSample} bits`,
    );
  }
  if (format.channelCount < 1 || format.sampleRate < 1) throw new Error("nonsense fmt chunk");

  const frameBytes = format.channelCount * 2;
  const frameCount = Math.floor(data.length / frameBytes);
  const dataView = new DataView(data.buffer, data.byteOffset, data.byteLength);
  const channels = Array.from({ length: format.channelCount }, () => new Float64Array(frameCount));
  for (let frame = 0; frame < frameCount; frame++) {
    for (let channel = 0; channel < format.channelCount; channel++) {
      channels[channel]![frame] = dataView.getInt16(frame * frameBytes + channel * 2, true) / 32768;
    }
  }

  return { sampleRate: format.sampleRate, channels };
};

// In-place iterative radix-2 FFT. Lengths are powers of two by construction.
const fft = (real: Float64Array, imag: Float64Array): void => {
  const n = real.length;
  for (let i = 1, j = 0; i < n; i++) {
    let bit = n >> 1;
    for (; j & bit; bit >>= 1) j ^= bit;
    j ^= bit;
    if (i < j) {
      [real[i]!, real[j]!] = [real[j]!, real[i]!];
      [imag[i]!, imag[j]!] = [imag[j]!, imag[i]!];
    }
  }
  for (let length = 2; length <= n; length <<= 1) {
    const angle = (-2 * Math.PI) / length;
    const wRe = Math.cos(angle);
    const wIm = Math.sin(angle);
    for (let start = 0; start < n; start += length) {
      let curRe = 1;
      let curIm = 0;
      for (let k = 0; k < length / 2; k++) {
        const even = start + k;
        const odd = start + k + length / 2;
        const oddRe = real[odd]! * curRe - imag[odd]! * curIm;
        const oddIm = real[odd]! * curIm + imag[odd]! * curRe;
        real[odd] = real[even]! - oddRe;
        imag[odd] = imag[even]! - oddIm;
        real[even] = real[even]! + oddRe;
        imag[even] = imag[even]! + oddIm;
        const nextRe = curRe * wRe - curIm * wIm;
        curIm = curRe * wIm + curIm * wRe;
        curRe = nextRe;
      }
    }
  }
};

export interface SpectralPeak {
  readonly frequencyHz: number;
  /** Relative to the strongest peak, which sits at 0. */
  readonly relativeDb: number;
}

export interface ChannelReport {
  readonly peakDbfs: number;
  readonly rmsDbfs: number;
  readonly silent: boolean;
  readonly windowStartSeconds: number;
  readonly windowSeconds: number;
  readonly peaks: ReadonlyArray<SpectralPeak>;
}

const toDb = (amplitude: number): number => 20 * Math.log10(Math.max(amplitude, 1e-10));

// Below this a recording is boot noise and dither, not a tone.
const silenceFloorDbfs = -60;
const maxWindowSize = 1 << 16;
const reportedPeakCount = 5;

/**
 * Measures one channel: overall level, then the dominant frequencies of the
 * loudest stretch. A recording starts with boot silence, so the FFT window is
 * placed over the highest-energy region rather than the start.
 */
export const analyzeChannel = (samples: Float64Array, sampleRate: number): ChannelReport => {
  let peak = 0;
  let energy = 0;
  for (const sample of samples) {
    peak = Math.max(peak, Math.abs(sample));
    energy += sample * sample;
  }
  const rmsDbfs = toDb(Math.sqrt(energy / Math.max(samples.length, 1)));

  let windowSize = maxWindowSize;
  while (windowSize > samples.length) windowSize >>= 1;
  const silent = rmsDbfs < silenceFloorDbfs || windowSize < 2;
  if (silent) {
    return {
      peakDbfs: toDb(peak),
      rmsDbfs,
      silent,
      windowStartSeconds: 0,
      windowSeconds: 0,
      peaks: [],
    };
  }

  let windowStart = 0;
  let bestEnergy = -1;
  const step = windowSize >> 2;
  for (let start = 0; start + windowSize <= samples.length; start += step) {
    let sum = 0;
    for (let i = start; i < start + windowSize; i++) sum += samples[i]! * samples[i]!;
    if (sum > bestEnergy) {
      bestEnergy = sum;
      windowStart = start;
    }
  }

  // Hann window keeps one tone from smearing across the whole spectrum.
  const real = new Float64Array(windowSize);
  const imag = new Float64Array(windowSize);
  for (let i = 0; i < windowSize; i++) {
    const hann = 0.5 - 0.5 * Math.cos((2 * Math.PI * i) / (windowSize - 1));
    real[i] = samples[windowStart + i]! * hann;
  }
  fft(real, imag);

  const binCount = windowSize / 2;
  const magnitudeDb = new Float64Array(binCount);
  for (let bin = 0; bin < binCount; bin++) {
    magnitudeDb[bin] = toDb(Math.hypot(real[bin]!, imag[bin]!));
  }

  const binHz = sampleRate / windowSize;
  const firstAudibleBin = Math.max(1, Math.ceil(20 / binHz));
  const candidates: Array<{ frequencyHz: number; db: number }> = [];
  for (let bin = firstAudibleBin; bin < binCount - 1; bin++) {
    const center = magnitudeDb[bin]!;
    if (center <= magnitudeDb[bin - 1]! || center < magnitudeDb[bin + 1]!) continue;
    // Parabolic interpolation recovers the frequency between bins.
    const left = magnitudeDb[bin - 1]!;
    const right = magnitudeDb[bin + 1]!;
    const denominator = left - 2 * center + right;
    const shift = denominator === 0 ? 0 : (0.5 * (left - right)) / denominator;
    candidates.push({ frequencyHz: (bin + shift) * binHz, db: center });
  }

  candidates.sort((a, b) => b.db - a.db);
  const strongestDb = candidates[0]?.db ?? 0;
  const peaks = candidates
    .filter((candidate) => candidate.db > strongestDb - 40)
    .slice(0, reportedPeakCount)
    .map((candidate) => ({
      frequencyHz: candidate.frequencyHz,
      relativeDb: candidate.db - strongestDb,
    }));

  return {
    peakDbfs: toDb(peak),
    rmsDbfs,
    silent,
    windowStartSeconds: windowStart / sampleRate,
    windowSeconds: windowSize / sampleRate,
    peaks,
  };
};

const channelName = (index: number, total: number): string =>
  total === 2 ? ["left", "right"][index]! : `ch${index}`;

const formatChannel = (name: string, report: ChannelReport): Array<string> => {
  const level =
    `${name.padEnd(5)}  peak ${report.peakDbfs.toFixed(1)} dBFS` +
    `  rms ${report.rmsDbfs.toFixed(1)} dBFS`;
  if (report.silent) return [`${level}  silent`];
  const window =
    `  window ${report.windowSeconds.toFixed(2)}s` + ` at ${report.windowStartSeconds.toFixed(2)}s`;
  const peaks = report.peaks.map(
    (peak) =>
      `       ${peak.frequencyHz.toFixed(1).padStart(8)} Hz  ${peak.relativeDb.toFixed(1).padStart(6)} dB`,
  );
  return [level + window, ...peaks];
};

export const analyzeWav = Effect.fn("analyzeWav")(function* (path: string) {
  const fileSystem = yield* FileSystem.FileSystem;

  const bytes = yield* fileSystem
    .readFile(path)
    .pipe(Effect.mapError((cause) => new WavReadError({ path, cause })));

  const audio = yield* Effect.try({
    try: () => parseWav(bytes),
    catch: (cause) => new WavParseError({ path, cause }),
  });

  const frameCount = audio.channels[0]?.length ?? 0;
  const seconds = frameCount / audio.sampleRate;
  yield* Console.log(
    `${path}  ${audio.sampleRate} Hz  ${audio.channels.length} channel(s)  ${seconds.toFixed(2)}s`,
  );

  const reports = audio.channels.map((samples) => analyzeChannel(samples, audio.sampleRate));
  for (const [index, report] of reports.entries()) {
    for (const line of formatChannel(channelName(index, reports.length), report)) {
      yield* Console.log(line);
    }
  }

  return reports;
});

export const analyzeWavCommand = Command.make(
  "analyze-wav",
  {
    file: Argument.string("file").pipe(
      Argument.withDescription("WAV file to analyze, e.g. a Mednafen -soundrecord capture."),
    ),
  },
  ({ file }) => analyzeWav(file),
).pipe(
  Command.withDescription("Report levels and dominant frequencies for each channel of a WAV file."),
);

if (import.meta.main) {
  Command.run(analyzeWavCommand, { version: "0.0.0" }).pipe(
    Effect.provide(NodeServices.layer),
    NodeRuntime.runMain,
  );
}
