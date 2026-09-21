//
//  KitoHaptics.swift
//  KitoHaptics
//
//  Created by Wycliff on 6/10/26.
//  Copyright © 2026 wyksoftsinc.com. All rights reserved.
//

import UIKit

/// Semantic haptics — call `.success()`, not "make a `UINotificationFeedbackGenerator`
/// and remember which enum case means success." One place owns generator
/// lifecycle (`prepare()` before firing reduces latency) and respects
/// `KitoHaptics.isEnabled` so a settings toggle disables every haptic in the
/// app at once.
public enum KitoHaptics {
    /// Global kill switch. Screens/settings can bind a toggle to this instead
    /// of threading an "enabled" flag through every call site.
    public static var isEnabled = true

    public static func success() {
        guard isEnabled else { return }
        let generator = UINotificationFeedbackGenerator()
        generator.prepare()
        generator.notificationOccurred(.success)
    }

    public static func warning() {
        guard isEnabled else { return }
        let generator = UINotificationFeedbackGenerator()
        generator.prepare()
        generator.notificationOccurred(.warning)
    }

    public static func error() {
        guard isEnabled else { return }
        let generator = UINotificationFeedbackGenerator()
        generator.prepare()
        generator.notificationOccurred(.error)
    }

    public static func selectionChanged() {
        guard isEnabled else { return }
        let generator = UISelectionFeedbackGenerator()
        generator.prepare()
        generator.selectionChanged()
    }

    public enum ImpactStyle {
        case light, medium, heavy, soft, rigid

        var uiKitStyle: UIImpactFeedbackGenerator.FeedbackStyle {
            switch self {
            case .light: return .light
            case .medium: return .medium
            case .heavy: return .heavy
            case .soft: return .soft
            case .rigid: return .rigid
            }
        }
    }

    public static func impact(_ style: ImpactStyle = .medium) {
        guard isEnabled else { return }
        let generator = UIImpactFeedbackGenerator(style: style.uiKitStyle)
        generator.prepare()
        generator.impactOccurred()
    }
}
