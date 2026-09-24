//
//  KitoHapticPatternTests.swift
//  KitoHaptics
//
//  Created by Wycliff on 9/24/26.
//  Copyright © 2026 wyksoftsinc.com. All rights reserved.
//

import XCTest
@testable import KitoHaptics

final class KitoHapticPatternTests: XCTestCase {
    func testEventClampsIntensitySharpnessAndTime() {
        let event = KitoHapticEvent(time: -1, intensity: 1.8, sharpness: -0.4, endIntensity: 3)
        XCTAssertEqual(event.time, 0)
        XCTAssertEqual(event.intensity, 1)
        XCTAssertEqual(event.sharpness, 0)
        XCTAssertEqual(event.endIntensity, 1)
    }

    func testPatternSortsEventsAndMeasuresDuration() {
        let pattern = KitoHapticPattern.custom([
            .hold(at: 0.3, duration: 0.5),
            .tap(at: 0),
        ])
        XCTAssertEqual(pattern.events.first?.time, 0)
        XCTAssertEqual(pattern.duration, 0.8, accuracy: 0.0001)
    }

    func testRampInterpolatesIntensity() {
        let ramp = KitoHapticEvent.hold(at: 1, duration: 1, intensity: 0, endIntensity: 1)
        XCTAssertEqual(ramp.intensity(at: 1.5), 0.5, accuracy: 0.0001)
        XCTAssertEqual(ramp.intensity(at: 0.5), 0)
        XCTAssertEqual(ramp.intensity(at: 2.5), 0)
    }

    func testTransientDecaysToZero() {
        let tap = KitoHapticEvent.tap(at: 0, intensity: 1)
        XCTAssertEqual(tap.intensity(at: 0), 1, accuracy: 0.0001)
        XCTAssertLessThan(tap.intensity(at: 0.03), 0.5)
    }

    func testSamplesCoverTheWholePattern() {
        let samples = KitoHapticPattern.rampUp.samples(count: 11)
        XCTAssertEqual(samples.count, 11)
        XCTAssertLessThan(samples[0], samples[5])
    }

    func testRepeatedShiftsEachRound() {
        let twice = KitoHapticPattern.knock.repeated(2, gap: 0.5)
        XCTAssertEqual(twice.events.count, KitoHapticPattern.knock.events.count * 2)
        XCTAssertEqual(twice.duration, KitoHapticPattern.knock.duration * 2 + 0.5, accuracy: 0.0001)
    }

    func testScaledReducesIntensity() {
        let gentle = KitoHapticPattern.rumble.scaled(by: 0.5)
        XCTAssertEqual(gentle.events[0].intensity, KitoHapticPattern.rumble.events[0].intensity * 0.5, accuracy: 0.0001)
    }

    func testPresetsAreDistinctAndPlayable() throws {
        XCTAssertEqual(Set(KitoHapticPattern.presets.map(\.name)).count, KitoHapticPattern.presets.count)
        for preset in KitoHapticPattern.presets {
            XCTAssertFalse(preset.events.isEmpty, preset.name)
            XCTAssertGreaterThan(preset.duration, 0, preset.name)
            XCTAssertNoThrow(try preset.coreHapticsPattern(), preset.name)
        }
    }

    func testTicksBuilder() {
        let ticks = KitoHapticPattern.ticks(count: 4, interval: 0.1)
        XCTAssertEqual(ticks.events.count, 4)
        XCTAssertEqual(ticks.events.last?.time ?? 0, 0.3, accuracy: 0.0001)
    }

    func testFallbackTurnsBuzzesIntoTapsAndSkipsSilence() {
        let pattern = KitoHapticPattern.custom([
            .tap(at: 0, intensity: 1, sharpness: 1),
            .hold(at: 0.1, duration: 0.3, intensity: 0.8, sharpness: 0),
            .tap(at: 0.5, intensity: 0),
        ])
        let impacts = pattern.fallbackImpacts(buzzInterval: 0.1)
        XCTAssertEqual(impacts.count, 4)
        XCTAssertEqual(impacts.first?.style, .rigid)
        XCTAssertEqual(impacts.last?.style, .soft)
    }

    func testSharpnessMapsToImpactWeights() {
        XCTAssertEqual(KitoHapticImpact.style(forSharpness: 0.1), .soft)
        XCTAssertEqual(KitoHapticImpact.style(forSharpness: 0.4), .medium)
        XCTAssertEqual(KitoHapticImpact.style(forSharpness: 0.6), .heavy)
        XCTAssertEqual(KitoHapticImpact.style(forSharpness: 0.9), .rigid)
    }

    func testVisualizerEnvelopeWidensTaps() {
        let tap = KitoHapticPattern.custom([.tap(at: 0.5, intensity: 1)])
        XCTAssertEqual(KitoHapticVisualizerMath.envelope(of: tap, at: 0.5), 1, accuracy: 0.0001)
        XCTAssertGreaterThan(KitoHapticVisualizerMath.envelope(of: tap, at: 0.52), 0.5)
        XCTAssertLessThan(KitoHapticVisualizerMath.envelope(of: tap, at: 0.8), 0.01)
    }
}
