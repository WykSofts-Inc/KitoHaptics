//
//  KitoHapticPattern.swift
//  KitoHaptics
//
//  Created by Wycliff on 9/24/26.
//  Copyright © 2026 wyksoftsinc.com. All rights reserved.
//

import Foundation

/// One beat in a `KitoHapticPattern`: a short tap (`transient`) or a held buzz
/// (`continuous`), with Core Haptics' intensity and sharpness, both 0...1.
public struct KitoHapticEvent: Equatable, Hashable, Sendable {
    public enum Kind: Equatable, Hashable, Sendable {
        /// A single tap, like a click.
        case transient
        /// A buzz held for `duration` seconds.
        case continuous(duration: TimeInterval)
    }

    /// Seconds from the start of the pattern.
    public var time: TimeInterval
    public var kind: Kind
    /// How strong it feels, 0...1.
    public var intensity: Double
    /// How crisp it feels: 0 is a dull thud, 1 a sharp click.
    public var sharpness: Double
    /// For a continuous event, the intensity it fades to by its end — a ramp.
    /// `nil` holds `intensity` steady.
    public var endIntensity: Double?

    public init(time: TimeInterval, kind: Kind = .transient, intensity: Double = 1, sharpness: Double = 0.5, endIntensity: Double? = nil) {
        self.time = max(time, 0)
        if case .continuous(let duration) = kind {
            self.kind = .continuous(duration: max(duration, 0.01))
        } else {
            self.kind = kind
        }
        self.intensity = Self.clamp(intensity)
        self.sharpness = Self.clamp(sharpness)
        self.endIntensity = endIntensity.map(Self.clamp)
    }

    /// A tap at `time`.
    public static func tap(at time: TimeInterval, intensity: Double = 1, sharpness: Double = 0.5) -> KitoHapticEvent {
        KitoHapticEvent(time: time, kind: .transient, intensity: intensity, sharpness: sharpness)
    }

    /// A buzz from `time` for `duration`, optionally ramping to `endIntensity`.
    public static func hold(at time: TimeInterval, duration: TimeInterval, intensity: Double = 1, sharpness: Double = 0.5,
                            endIntensity: Double? = nil) -> KitoHapticEvent {
        KitoHapticEvent(time: time, kind: .continuous(duration: duration), intensity: intensity, sharpness: sharpness, endIntensity: endIntensity)
    }

    /// How long the event lasts. Transient taps count as a brief 40 ms blip.
    public var duration: TimeInterval {
        switch kind {
        case .transient: return KitoHapticEvent.transientLength
        case .continuous(let duration): return duration
        }
    }

    public var endTime: TimeInterval { time + duration }

    public var isTransient: Bool { kind == .transient }

    /// The felt intensity at `moment`, 0 outside the event.
    public func intensity(at moment: TimeInterval) -> Double {
        guard moment >= time, moment <= endTime else { return 0 }
        switch kind {
        case .transient:
            // A quick attack and decay, so a tap draws as a spike, not a block.
            let progress = (moment - time) / KitoHapticEvent.transientLength
            return intensity * max(0, 1 - progress)
        case .continuous(let duration):
            guard let endIntensity else { return intensity }
            let progress = min(max((moment - time) / duration, 0), 1)
            return intensity + (endIntensity - intensity) * progress
        }
    }

    static let transientLength: TimeInterval = 0.04

    private static func clamp(_ value: Double) -> Double { min(max(value, 0), 1) }
}

/// A named sequence of haptic events — play it with `KitoHaptics.play(_:)` and
/// draw it with `KitoHapticVisualizer`. Start from a preset (`.heartbeat`,
/// `.successChime`, `.rumble`, …) or build your own with `.custom(_:)`.
public struct KitoHapticPattern: Equatable, Hashable, Sendable, Identifiable {
    public var name: String
    /// Sorted by start time.
    public var events: [KitoHapticEvent]

    public var id: String { name }

    public init(name: String = "Custom", events: [KitoHapticEvent]) {
        self.name = name
        self.events = events.sorted { $0.time < $1.time }
    }

    /// A pattern from your own events.
    public static func custom(_ events: [KitoHapticEvent], name: String = "Custom") -> KitoHapticPattern {
        KitoHapticPattern(name: name, events: events)
    }

    /// When the last event finishes.
    public var duration: TimeInterval { events.map(\.endTime).max() ?? 0 }

    /// The strongest felt intensity of any event at `moment`.
    public func intensity(at moment: TimeInterval) -> Double {
        events.reduce(0) { max($0, $1.intensity(at: moment)) }
    }

    /// `count` evenly spaced intensity samples across the whole pattern, for drawing a waveform.
    public func samples(count: Int) -> [Double] {
        guard count > 1, duration > 0 else { return Array(repeating: 0, count: max(count, 0)) }
        return (0..<count).map { intensity(at: duration * Double($0) / Double(count - 1)) }
    }

    /// The same pattern played `times` times, `gap` seconds apart.
    public func repeated(_ times: Int, gap: TimeInterval = 0.2) -> KitoHapticPattern {
        guard times > 1 else { return self }
        let length = duration + gap
        let all = (0..<times).flatMap { round in
            events.map { event in
                var copy = event
                copy.time += length * Double(round)
                return copy
            }
        }
        return KitoHapticPattern(name: name, events: all)
    }

    /// Every intensity scaled by `factor`, e.g. 0.5 for a gentler version.
    public func scaled(by factor: Double) -> KitoHapticPattern {
        KitoHapticPattern(name: name, events: events.map { event in
            KitoHapticEvent(time: event.time, kind: event.kind, intensity: event.intensity * factor, sharpness: event.sharpness,
                            endIntensity: event.endIntensity.map { $0 * factor })
        })
    }
}

// MARK: - Presets

public extension KitoHapticPattern {
    /// Lub-dub, twice — a living, "alive" pulse.
    static let heartbeat = KitoHapticPattern(name: "Heartbeat", events: [
        .tap(at: 0, intensity: 1, sharpness: 0.3),
        .tap(at: 0.14, intensity: 0.6, sharpness: 0.2),
        .tap(at: 0.8, intensity: 1, sharpness: 0.3),
        .tap(at: 0.94, intensity: 0.6, sharpness: 0.2),
    ])

    /// Three rising, brightening taps — "done, and it went well."
    static let successChime = KitoHapticPattern(name: "Success chime", events: [
        .tap(at: 0, intensity: 0.5, sharpness: 0.4),
        .tap(at: 0.1, intensity: 0.75, sharpness: 0.6),
        .tap(at: 0.22, intensity: 1, sharpness: 0.9),
        .hold(at: 0.22, duration: 0.18, intensity: 0.35, sharpness: 0.8, endIntensity: 0),
    ])

    /// Crisp, even clicks, like a dial turning.
    static let ticks = KitoHapticPattern.ticks(count: 8, interval: 0.07)

    /// `count` crisp clicks, `interval` seconds apart.
    static func ticks(count: Int, interval: TimeInterval) -> KitoHapticPattern {
        KitoHapticPattern(name: "Ticks", events: (0..<max(count, 1)).map {
            .tap(at: Double($0) * interval, intensity: 0.55, sharpness: 1)
        })
    }

    /// A low, heavy engine rumble with a few bumps on top.
    static let rumble = KitoHapticPattern(name: "Rumble", events: [
        .hold(at: 0, duration: 0.9, intensity: 0.8, sharpness: 0.05),
        .tap(at: 0.15, intensity: 0.7, sharpness: 0.1),
        .tap(at: 0.45, intensity: 0.9, sharpness: 0.1),
        .tap(at: 0.72, intensity: 0.6, sharpness: 0.1),
    ])

    /// Knock, knock — two firm, woody taps.
    static let knock = KitoHapticPattern(name: "Knock", events: [
        .tap(at: 0, intensity: 1, sharpness: 0.55),
        .tap(at: 0.18, intensity: 0.9, sharpness: 0.55),
    ])

    /// A buzz that swells from nothing to full.
    static let rampUp = KitoHapticPattern(name: "Ramp up", events: [
        .hold(at: 0, duration: 0.8, intensity: 0.05, sharpness: 0.4, endIntensity: 1),
        .tap(at: 0.8, intensity: 1, sharpness: 0.8),
    ])

    /// A strong buzz that fades away.
    static let rampDown = KitoHapticPattern(name: "Ramp down", events: [
        .tap(at: 0, intensity: 1, sharpness: 0.8),
        .hold(at: 0, duration: 0.8, intensity: 1, sharpness: 0.4, endIntensity: 0),
    ])

    /// A sharp buzz then a thud — "that didn't work."
    static let failure = KitoHapticPattern(name: "Failure", events: [
        .tap(at: 0, intensity: 0.9, sharpness: 0.9),
        .tap(at: 0.09, intensity: 0.9, sharpness: 0.9),
        .hold(at: 0.2, duration: 0.25, intensity: 0.7, sharpness: 0.1, endIntensity: 0.1),
    ])

    /// A soft double tap, like a nudge on the shoulder.
    static let nudge = KitoHapticPattern(name: "Nudge", events: [
        .tap(at: 0, intensity: 0.45, sharpness: 0.25),
        .tap(at: 0.12, intensity: 0.45, sharpness: 0.25),
    ])

    /// Every built-in pattern, for pickers and galleries.
    static let presets: [KitoHapticPattern] = [.heartbeat, .successChime, .ticks, .rumble, .knock, .rampUp, .rampDown, .failure, .nudge]
}
