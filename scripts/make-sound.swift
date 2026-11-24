// Synthesizes Support/Knock.wav, the meeting panel's sound (meeting-alerts R35): NextUp's own knock in the style
// of Slack's Knock Brush, a soft high brush and then three short knocks. Foundation only; the WAV is written by
// hand. Run from the repo root:
//     swift scripts/make-sound.swift && afplay Support/Knock.wav
import Foundation

// Tuning knobs.
let rate = 44_100.0
let length = 0.5                                  // s
let gain = 0.385                                  // peak, of 1: -8.3 dBFS
let brushLength = 0.075                           // s, the swish before the knocks
let brushLevel = 0.06                             // of a knock's peak
let knocks = [0.233, 0.367, 0.467]                // s, onsets
let pitch = 1210.0                                // Hz
let overtone = (ratio: 2.7, weight: 0.07)
let attack = 0.005                                // s
let decay = 0.003                                 // s, time constant of each knock's fade

var samples = [Double](repeating: 0, count: Int(length * rate))

// The brush: white noise, band-passed around 11 kHz, in a 12 ms fade-in / 15 ms fade-out.
var seed: UInt32 = 1  // a fixed LCG, so every run writes the same file
func noise() -> Double { seed = seed &* 1_664_525 &+ 1_013_904_223; return Double(seed) / Double(UInt32.max) * 2 - 1 }
var (n1, n2) = (0.0, 0.0)
for i in 0..<min(Int(brushLength * rate), samples.count) {
    let t = Double(i) / rate
    let n0 = noise()
    let high = n0 - n2  // a band-pass that peaks at a quarter of the rate, 11 kHz
    (n2, n1) = (n1, n0)
    samples[i] += brushLevel * min(t / 0.012, 1, (brushLength - t) / 0.015) * high / 2
}

// The knocks: a sine with a weak inharmonic overtone, a fast attack and a fast exponential fade.
for onset in knocks {
    for i in min(Int(onset * rate), samples.count)..<samples.count {
        let t = Double(i) / rate - onset
        let envelope = min(t / attack, 1) * exp(-t / decay)
        if t > attack, envelope < 1e-5 { break }
        samples[i] += envelope * (sin(2 * .pi * pitch * t) + overtone.weight * sin(2 * .pi * pitch * overtone.ratio * t))
    }
}

let peak = samples.map(abs).max() ?? 1
let pcm = samples.map { Int16(($0 / peak * gain * Double(Int16.max)).rounded()) }

var data = Data()
func put<T: FixedWidthInteger>(_ value: T) { withUnsafeBytes(of: value.littleEndian) { data.append(contentsOf: $0) } }
let bytes = UInt32(pcm.count * 2)
data.append(contentsOf: Array("RIFF".utf8)); put(36 + bytes); data.append(contentsOf: Array("WAVE".utf8))
data.append(contentsOf: Array("fmt ".utf8)); put(UInt32(16)); put(UInt16(1)); put(UInt16(1))
put(UInt32(rate)); put(UInt32(rate) * 2); put(UInt16(2)); put(UInt16(16))
data.append(contentsOf: Array("data".utf8)); put(bytes)
for s in pcm { put(s) }
try data.write(to: URL(fileURLWithPath: "Support/Knock.wav"))
print("Support/Knock.wav: \(pcm.count) samples")
