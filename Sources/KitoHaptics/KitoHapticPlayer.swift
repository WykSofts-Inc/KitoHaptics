//
//  KitoHapticPlayer.swift
//  KitoHaptics
//
//  Created by Wycliff on 9/24/26.
//  Copyright © 2026 wyksoftsinc.com. All rights reserved.
//

import CoreHaptics
import UIKit

public extension KitoHaptics {
    /// Whether this device has a Taptic Engine Core Haptics can drive. `false` on the
    /// simulator, iPads and older iPhones, where `play(_:)` falls back to impacts.
    static var supportsCoreHaptics: Bool {
        CHHapticEngine.capabilitiesForHardware().supportsHaptics
    }

    /// Plays `pattern` with Core Haptics, or, where Core Haptics isn't available, as a
    /// sequence of `UIImpactFeedbackGenerator` taps approximating it. Respects `isEnabled`.
    @MainActor
    static func play(_ pattern: KitoHapticPattern) {
        guard isEnabled, !pattern.events.isEmpty else { return }
        if supportsCoreHaptics, KitoHapticEngine.shared.play(pattern) { return }
        KitoHapticFallback.play(pattern)
    }

    /// Stops a pattern that's still playing.
    @MainActor
    static func stopPattern() {
        KitoHapticEngine.shared.stop()
        KitoHapticFallback.cancel()
    }
}

// MARK: - Core Haptics

/// Owns one `CHHapticEngine` for the app, started lazily and restarted after the
/// system stops or resets it (e.g. when the app goes to the background).
@MainActor
final class KitoHapticEngine {
    static let shared = KitoHapticEngine()

    private var engine: CHHapticEngine?
    private var player: CHHapticAdvancedPatternPlayer?

    func play(_ pattern: KitoHapticPattern) -> Bool {
        do {
            let engine = try readyEngine()
            try player?.stop(atTime: CHHapticTimeImmediate)
            let player = try engine.makeAdvancedPlayer(with: try pattern.coreHapticsPattern())
            try player.start(atTime: CHHapticTimeImmediate)
            self.player = player
            return true
        } catch {
            return false
        }
    }

    func stop() {
        try? player?.stop(atTime: CHHapticTimeImmediate)
        player = nil
    }

    private func readyEngine() throws -> CHHapticEngine {
        if let engine {
            try engine.start()
            return engine
        }
        let engine = try CHHapticEngine()
        engine.isAutoShutdownEnabled = true
        engine.resetHandler = { [weak engine] in try? engine?.start() }
        try engine.start()
        self.engine = engine
        return engine
    }
}

extension KitoHapticPattern {
    /// The Core Haptics form: one `CHHapticEvent` per event, plus an intensity curve
    /// for each ramping continuous event.
    func coreHapticsPattern() throws -> CHHapticPattern {
        var hapticEvents: [CHHapticEvent] = []
        var curves: [CHHapticParameterCurve] = []

        for event in events {
            let sharpness = CHHapticEventParameter(parameterID: .hapticSharpness, value: Float(event.sharpness))
            switch event.kind {
            case .transient:
                let intensity = CHHapticEventParameter(parameterID: .hapticIntensity, value: Float(event.intensity))
                hapticEvents.append(CHHapticEvent(eventType: .hapticTransient, parameters: [intensity, sharpness], relativeTime: event.time))
            case .continuous(let duration):
                // A curve can only scale an event's intensity down, so the event plays at the
                // ramp's peak and the curve runs from start/peak to end/peak.
                let peak = max(event.intensity, event.endIntensity ?? event.intensity, 0.001)
                let intensity = CHHapticEventParameter(parameterID: .hapticIntensity, value: Float(peak))
                hapticEvents.append(CHHapticEvent(eventType: .hapticContinuous, parameters: [intensity, sharpness],
                                                  relativeTime: event.time, duration: duration))
                if let end = event.endIntensity {
                    curves.append(CHHapticParameterCurve(parameterID: .hapticIntensityControl, controlPoints: [
                        .init(relativeTime: 0, value: Float(event.intensity / peak)),
                        .init(relativeTime: duration, value: Float(end / peak)),
                    ], relativeTime: event.time))
                }
            }
        }
        return try CHHapticPattern(events: hapticEvents, parameterCurves: curves)
    }
}

// MARK: - Fallback

/// One `UIImpactFeedbackGenerator` tap standing in for part of a pattern.
struct KitoHapticImpact: Equatable {
    var time: TimeInterval
    var intensity: Double
    var style: KitoHaptics.ImpactStyle
}

extension KitoHapticPattern {
    /// The taps that approximate this pattern on devices without Core Haptics: one per
    /// transient, and one every 60 ms through a continuous buzz.
    func fallbackImpacts(buzzInterval: TimeInterval = 0.06) -> [KitoHapticImpact] {
        events.flatMap { event -> [KitoHapticImpact] in
            let style = KitoHapticImpact.style(forSharpness: event.sharpness)
            switch event.kind {
            case .transient:
                return [KitoHapticImpact(time: event.time, intensity: event.intensity, style: style)]
            case .continuous(let duration):
                let count = max(Int(duration / buzzInterval), 1)
                return (0..<count).map { step in
                    let moment = event.time + Double(step) * buzzInterval
                    return KitoHapticImpact(time: moment, intensity: event.intensity(at: moment), style: style)
                }
            }
        }
        .filter { $0.intensity > 0.02 }
        .sorted { $0.time < $1.time }
    }
}

extension KitoHapticImpact {
    static func style(forSharpness sharpness: Double) -> KitoHaptics.ImpactStyle {
        switch sharpness {
        case ..<0.25: return .soft
        case ..<0.5: return .medium
        case ..<0.75: return .heavy
        default: return .rigid
        }
    }
}

@MainActor
enum KitoHapticFallback {
    private static var generation = 0

    static func play(_ pattern: KitoHapticPattern) {
        generation += 1
        let current = generation
        let start = DispatchTime.now()
        for impact in pattern.fallbackImpacts() {
            DispatchQueue.main.asyncAfter(deadline: start + impact.time) {
                guard current == generation, KitoHaptics.isEnabled else { return }
                let generator = UIImpactFeedbackGenerator(style: impact.style.uiKitStyle)
                generator.impactOccurred(intensity: CGFloat(impact.intensity))
            }
        }
    }

    static func cancel() { generation += 1 }
}
