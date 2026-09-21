# KitoHaptics

Semantic haptic feedback — call what you mean, not a feedback-generator type.

## Install

```swift
.package(url: "https://github.com/WykSofts-Inc/KitoHaptics.git", from: "1.0.0"),
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

## License

MIT
