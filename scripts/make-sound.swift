// Synthesizes Support/Knock.wav, the meeting panel's sound (meeting-alerts R35): NextUp's own two-note
// wooden knock in the style of Slack's. Foundation only; the WAV is written by hand. Run from the repo root:
//     swift scripts/make-sound.swift && afplay Support/Knock.wav
import Foundation

// Tuning knobs.
let rate = 44_100.0
let notes: [(start: Double, pitch: Double)] = [(0, 660), (0.09, 990)]  // seconds, Hz: a fifth up
let partials: [(ratio: Double, weight: Double)] = [(1, 1), (4, 0.25), (10, 0.06)]  // marimba-like bar
let attack = 0.002     // s
let decay = 0.07       // s, time constant of the exponential fade
let length = 0.45      // s
let gain = 0.5         // peak, of 1

var samples = [Double](repeating: 0, count: Int(length * rate))
for note in notes {
    for i in Int(note.start * rate)..<samples.count {
        let t = Double(i) / rate - note.start
        let envelope = min(t / attack, 1) * exp(-t / decay)
        for p in partials {
            // Higher partials fade faster, as on a struck bar.
            samples[i] += p.weight * envelope * exp(-t * p.ratio * 8) * sin(2 * .pi * note.pitch * p.ratio * t)
        }
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
