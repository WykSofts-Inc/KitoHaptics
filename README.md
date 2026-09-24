# KitoHaptics

**[Documentation](https://wyksofts-inc.github.io/KitoHaptics/documentation/kitohaptics/)**

Semantic haptic feedback — call what you mean, not a feedback-generator type.

## Install

```swift
.package(url: "https://github.com/WykSofts-Inc/KitoHaptics.git", from: "1.1.0"),
```

## Samples

```swift
Button("Save") {
    viewModel.save()
    KitoHaptics.success()
}

Button("Delete", role: .destructive) {
    viewModel.delete()
    KitoHaptics.warning()
}

Picker("Plan", selection: $plan) { /* ... */ }
    .onChange(of: plan) { _, _ in KitoHaptics.selectionChanged() }

// Custom impact weight
Button {
    withAnimation { isExpanded.toggle() }
    KitoHaptics.impact(.light)
} label: { /* ... */ }
```

**React to state changes instead of button taps:**
```swift
FieldView()
    .kitoHaptic(viewModel.hasValidationError) { KitoHaptics.error() }
```

**Respect a user setting:**
```swift
Toggle("Haptic feedback", isOn: Binding(
    get: { KitoHaptics.isEnabled },
    set: { KitoHaptics.isEnabled = $0 }
))
```

## Patterns

Core Haptics patterns for moments that deserve more than a single tap. On devices
without Core Haptics (the simulator, iPads, older iPhones) `play` falls back to a
sequence of impacts that approximates the pattern.

```swift
KitoHaptics.play(.heartbeat)
KitoHaptics.play(.successChime)
KitoHaptics.play(.ticks(count: 12, interval: 0.05))
KitoHaptics.play(.rumble.scaled(by: 0.6))

// Your own pattern
let drumroll = KitoHapticPattern.custom([
    .tap(at: 0, intensity: 0.6, sharpness: 0.8),
    .tap(at: 0.08, intensity: 0.7, sharpness: 0.8),
    .hold(at: 0.16, duration: 0.5, intensity: 0.2, sharpness: 0.5, endIntensity: 1),
], name: "Drumroll")
KitoHaptics.play(drumroll)

// Play when state changes
OrderStatusView(order)
    .kitoHapticPattern(.successChime, trigger: order.isDelivered)
```

Presets: `.heartbeat`, `.successChime`, `.ticks`, `.rumble`, `.knock`, `.rampUp`,
`.rampDown`, `.failure`, `.nudge` (all in `KitoHapticPattern.presets`).

## Visualizer

`KitoHapticVisualizer` draws a pattern: height is intensity, colour is sharpness.
Pass the time you played it and a playhead sweeps across, so the pattern reads
even where it can't be felt.

```swift
@State private var playedAt: Date?

KitoHapticVisualizer(.heartbeat, playedAt: playedAt, style: .waveform)
    .frame(height: 90)
Button("Play") {
    KitoHaptics.play(.heartbeat)
    playedAt = .now
}
```

## License

MIT
