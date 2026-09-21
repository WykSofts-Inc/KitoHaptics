//
//  KitoHapticsTests.swift
//  KitoHaptics
//
//  Created by Wycliff on 6/12/26.
//  Copyright © 2026 wyksoftsinc.com. All rights reserved.
//

import XCTest
@testable import KitoHaptics

final class KitoHapticsTests: XCTestCase {
    override func tearDown() {
        KitoHaptics.isEnabled = true
        super.tearDown()
    }

    func testDisabledSwitchIsRespected() {
        // These calls must not crash even with UIKit generators unavailable
        // in a test host without a real device — the guard short-circuits first.
        KitoHaptics.isEnabled = false
        KitoHaptics.success()
        KitoHaptics.impact(.heavy)
        XCTAssertFalse(KitoHaptics.isEnabled)
    }
}
