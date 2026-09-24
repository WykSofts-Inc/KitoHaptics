# ``KitoHaptics``

Semantic haptic feedback, Core Haptics patterns, and a visualiser for them.

## Overview

KitoHaptics lets you call what you mean — success, warning, error, a selection
change or an impact — instead of choosing a feedback-generator type. Every call
goes through ``KitoHaptics``, which also exposes an `isEnabled` switch you can
bind to a user setting.

```swift
Button("Save") {
    viewModel.save()
    KitoHaptics.success()
}

FieldView()
    .kitoHaptic(viewModel.hasValidationError) { KitoHaptics.error() }
```

For moments that deserve more than a single tap, play a ``KitoHapticPattern``:
a timeline of ``KitoHapticEvent`` taps and holds. The package ships presets such
as `.heartbeat`, `.successChime`, `.ticks` and `.rumble`, and you can build your
own, repeat them, or scale their intensity. On devices without Core Haptics —
the simulator, iPads and older iPhones — `play(_:)` falls back to a sequence of
impacts that approximates the pattern.

```swift
KitoHaptics.play(.heartbeat)

OrderStatusView(order)
    .kitoHapticPattern(.successChime, trigger: order.isDelivered)
```

``KitoHapticVisualizer`` draws a pattern, with height for intensity and colour
for sharpness. Pass the time you played it and a playhead sweeps across, so the
pattern still reads where it cannot be felt.

## Topics

### Essentials

- ``KitoHaptics``

### Patterns

- ``KitoHapticPattern``
- ``KitoHapticEvent``

### Visualisation

- ``KitoHapticVisualizer``
