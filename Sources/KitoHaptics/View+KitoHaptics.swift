//
//  View+KitoHaptics.swift
//  KitoHaptics
//
//  Created by Wycliff on 6/11/26.
//  Copyright © 2026 wyksoftsinc.com. All rights reserved.
//

import SwiftUI

public extension View {
    /// Fires a haptic whenever `trigger` changes — pair with a `@State` or
    /// ViewModel property instead of calling `KitoHaptics` from inside a
    /// button action when the trigger is a derived state change (e.g. a
    /// validation error appearing).
    func kitoHaptic<T: Equatable>(_ trigger: T, _ haptic: @escaping () -> Void) -> some View {
        onChange(of: trigger) { _, _ in haptic() }
    }
}
