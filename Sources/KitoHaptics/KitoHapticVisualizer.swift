//
//  KitoHapticVisualizer.swift
//  KitoHaptics
//
//  Created by Wycliff on 9/24/26.
//  Copyright © 2026 wyksoftsinc.com. All rights reserved.
//

import SwiftUI
import UIKit
import KitoCore

/// Draws a `KitoHapticPattern` over time: height is intensity, colour is sharpness
/// (warm for a dull thud, cool for a crisp click). Pass `playedAt` when you play the
/// pattern and a playhead sweeps across, lighting up each beat as it's felt — so the
/// pattern still reads on a device (or simulator) that can't play it.
public struct KitoHapticVisualizer: View {
    public enum Style: Sendable {
        /// Taps as capsules, buzzes as filled blocks.
        case bars
        /// A mirrored, audio-style envelope.
        case waveform
    }

    @Environment(\.kitoTheme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let pattern: KitoHapticPattern
    let playedAt: Date?
    let style: Style
    let softColor: Color?
    let sharpColor: Color?
    let showsGrid: Bool

    @State private var isAnimating = false

    public init(_ pattern: KitoHapticPattern, playedAt: Date? = nil, style: Style = .bars,
                softColor: Color? = nil, sharpColor: Color? = nil, showsGrid: Bool = true) {
        self.pattern = pattern
        self.playedAt = playedAt
        self.style = style
        self.softColor = softColor
        self.sharpColor = sharpColor
        self.showsGrid = showsGrid
    }

    public var body: some View {
        TimelineView(.animation(paused: !isAnimating)) { context in
            let elapsed = playedAt.map { context.date.timeIntervalSince($0) }
            Canvas { canvas, size in
                draw(in: &canvas, size: size, elapsed: elapsed)
            }
        }
        .frame(minHeight: 60)
        .task(id: playedAt) {
            // Animate only while the playhead is on screen.
            guard let playedAt else { isAnimating = false; return }
            isAnimating = true
            let remaining = timelineLength + 0.3 - Date.now.timeIntervalSince(playedAt)
            if remaining > 0 { try? await Task.sleep(nanoseconds: UInt64(remaining * 1_000_000_000)) }
            if !Task.isCancelled { isAnimating = false }
        }
        .accessibilityElement()
        .accessibilityLabel("\(pattern.name) haptic pattern")
        .accessibilityValue("\(pattern.events.count) beats over \(String(format: "%.1f", pattern.duration)) seconds")
    }

    /// A little breathing room after the last beat.
    private var timelineLength: TimeInterval { max(pattern.duration * 1.08, 0.1) }

    private var soft: Color { softColor ?? Color(red: 1.0, green: 0.46, blue: 0.32) }
    private var sharp: Color { sharpColor ?? theme.colors.primary }

    private func color(forSharpness sharpness: Double) -> Color {
        KitoHapticVisualizerMath.blend(soft, sharp, sharpness)
    }

    // MARK: Drawing

    private func draw(in canvas: inout GraphicsContext, size: CGSize, elapsed: TimeInterval?) {
        let inset: CGFloat = 6
        let plot = CGRect(x: inset, y: inset, width: size.width - inset * 2, height: size.height - inset * 2)
        let x = { (time: TimeInterval) -> CGFloat in plot.minX + CGFloat(time / timelineLength) * plot.width }

        if showsGrid { drawGrid(in: &canvas, plot: plot, x: x) }

        switch style {
        case .bars: drawBars(in: &canvas, plot: plot, x: x, elapsed: elapsed)
        case .waveform: drawWaveform(in: &canvas, plot: plot, x: x, elapsed: elapsed)
        }

        if let elapsed, elapsed >= 0, elapsed <= timelineLength {
            let playheadX = x(elapsed)
            var line = Path()
            line.move(to: CGPoint(x: playheadX, y: plot.minY - 2))
            line.addLine(to: CGPoint(x: playheadX, y: plot.maxY + 2))
            canvas.stroke(line, with: .color(theme.colors.onBackground.opacity(0.7)), style: StrokeStyle(lineWidth: 2, lineCap: .round))
            let knob = CGRect(x: playheadX - 4, y: plot.minY - 6, width: 8, height: 8)
            canvas.fill(Path(ellipseIn: knob), with: .color(theme.colors.onBackground))
        }
    }

    private func drawGrid(in canvas: inout GraphicsContext, plot: CGRect, x: (TimeInterval) -> CGFloat) {
        let gridColor = theme.colors.onBackground.opacity(0.08)
        for level in [0.25, 0.5, 0.75] {
            var line = Path()
            let y = style == .waveform ? plot.midY - CGFloat(level) * plot.height / 2 : plot.maxY - CGFloat(level) * plot.height
            line.move(to: CGPoint(x: plot.minX, y: y))
            line.addLine(to: CGPoint(x: plot.maxX, y: y))
            canvas.stroke(line, with: .color(gridColor), style: StrokeStyle(lineWidth: 1, dash: [3, 4]))
        }
        var baseline = Path()
        let baseY = style == .waveform ? plot.midY : plot.maxY
        baseline.move(to: CGPoint(x: plot.minX, y: baseY))
        baseline.addLine(to: CGPoint(x: plot.maxX, y: baseY))
        canvas.stroke(baseline, with: .color(theme.colors.onBackground.opacity(0.18)), lineWidth: 1)

        // A tick every tenth of a second.
        var tick = 0.0
        while tick <= timelineLength {
            let dot = CGRect(x: x(tick) - 1, y: plot.maxY + 3, width: 2, height: 2)
            canvas.fill(Path(ellipseIn: dot), with: .color(theme.colors.onBackground.opacity(0.25)))
            tick += 0.1
        }
    }

    private func drawBars(in canvas: inout GraphicsContext, plot: CGRect, x: (TimeInterval) -> CGFloat, elapsed: TimeInterval?) {
        // Buzzes first, so taps sit on top of them.
        for event in pattern.events where !event.isTransient {
            let color = color(forSharpness: event.sharpness)
            let start = x(event.time), end = x(event.endTime)
            let startHeight = CGFloat(event.intensity) * plot.height
            let endHeight = CGFloat(event.endIntensity ?? event.intensity) * plot.height
            var shape = Path()
            shape.move(to: CGPoint(x: start, y: plot.maxY))
            shape.addLine(to: CGPoint(x: start, y: plot.maxY - startHeight))
            shape.addLine(to: CGPoint(x: end, y: plot.maxY - endHeight))
            shape.addLine(to: CGPoint(x: end, y: plot.maxY))
            shape.closeSubpath()
            let lit = litAmount(for: event, elapsed: elapsed)
            canvas.fill(shape, with: .linearGradient(
                Gradient(colors: [color.opacity(0.45 + 0.35 * lit), color.opacity(0.08)]),
                startPoint: CGPoint(x: start, y: plot.minY), endPoint: CGPoint(x: start, y: plot.maxY)))
            var top = Path()
            top.move(to: CGPoint(x: start, y: plot.maxY - startHeight))
            top.addLine(to: CGPoint(x: end, y: plot.maxY - endHeight))
            canvas.stroke(top, with: .color(color), style: StrokeStyle(lineWidth: 2, lineCap: .round))
        }

        let barWidth = max(min(plot.width / CGFloat(max(pattern.events.count, 1)) * 0.35, 8), 4)
        for event in pattern.events where event.isTransient {
            let color = color(forSharpness: event.sharpness)
            let lit = litAmount(for: event, elapsed: elapsed)
            let grow = reduceMotion ? 1 : 1 + 0.12 * lit
            let height = max(CGFloat(event.intensity) * plot.height * grow, barWidth)
            let center = x(event.time)
            let rect = CGRect(x: center - barWidth / 2, y: plot.maxY - height, width: barWidth, height: height)
            if lit > 0 {
                var glow = canvas
                glow.addFilter(.blur(radius: 6))
                glow.fill(Path(roundedRect: rect.insetBy(dx: -3, dy: -3), cornerRadius: barWidth), with: .color(color.opacity(0.6 * lit)))
            }
            canvas.fill(Path(roundedRect: rect, cornerRadius: barWidth / 2), with: .linearGradient(
                Gradient(colors: [color, color.opacity(0.55)]),
                startPoint: CGPoint(x: center, y: rect.minY), endPoint: CGPoint(x: center, y: rect.maxY)))
        }
    }

    private func drawWaveform(in canvas: inout GraphicsContext, plot: CGRect, x: (TimeInterval) -> CGFloat, elapsed: TimeInterval?) {
        let count = max(Int(plot.width / 3), 24)
        let points: [(CGFloat, Double, Double)] = (0..<count).map { index in
            let time = timelineLength * Double(index) / Double(count - 1)
            let level = KitoHapticVisualizerMath.envelope(of: pattern, at: time)
            return (x(time), level, KitoHapticVisualizerMath.sharpness(of: pattern, at: time))
        }
        var shape = Path()
        shape.move(to: CGPoint(x: plot.minX, y: plot.midY))
        for point in points { shape.addLine(to: CGPoint(x: point.0, y: plot.midY - CGFloat(point.1) * plot.height / 2)) }
        for point in points.reversed() { shape.addLine(to: CGPoint(x: point.0, y: plot.midY + CGFloat(point.1) * plot.height / 2)) }
        shape.closeSubpath()

        let meanSharpness = pattern.events.isEmpty ? 0.5 : pattern.events.map(\.sharpness).reduce(0, +) / Double(pattern.events.count)
        let fill = GraphicsContext.Shading.linearGradient(
            Gradient(colors: [soft, color(forSharpness: meanSharpness), sharp]),
            startPoint: CGPoint(x: plot.minX, y: plot.midY), endPoint: CGPoint(x: plot.maxX, y: plot.midY))

        var dim = canvas
        dim.opacity = elapsed == nil ? 1 : 0.35
        dim.fill(shape, with: fill)

        if let elapsed, elapsed > 0 {
            var played = canvas
            played.clip(to: Path(CGRect(x: plot.minX, y: plot.minY - 4, width: x(elapsed) - plot.minX, height: plot.height + 8)))
            played.fill(shape, with: fill)
        }
    }

    /// 1 while the playhead is on the event, fading out over the next 0.25 s.
    private func litAmount(for event: KitoHapticEvent, elapsed: TimeInterval?) -> Double {
        guard let elapsed, elapsed >= event.time else { return 0 }
        if elapsed <= event.endTime { return 1 }
        return max(0, 1 - (elapsed - event.endTime) / 0.25)
    }
}

/// Pure helpers behind the drawing, separated out so they can be unit tested.
enum KitoHapticVisualizerMath {
    /// A smoothed envelope that widens taps so they read at any width.
    static func envelope(of pattern: KitoHapticPattern, at time: TimeInterval) -> Double {
        pattern.events.reduce(0) { level, event in
            if event.isTransient {
                let distance = abs(time - event.time)
                let spread = 0.035
                return max(level, event.intensity * exp(-(distance * distance) / (2 * spread * spread)))
            }
            return max(level, event.intensity(at: time))
        }
    }

    /// The sharpness of whichever event is loudest at `time`.
    static func sharpness(of pattern: KitoHapticPattern, at time: TimeInterval) -> Double {
        pattern.events.max { $0.intensity(at: time) < $1.intensity(at: time) }?.sharpness ?? 0.5
    }

    static func blend(_ from: Color, _ to: Color, _ amount: Double) -> Color {
        let a = UIColor(from), b = UIColor(to)
        var (r1, g1, b1, a1): (CGFloat, CGFloat, CGFloat, CGFloat) = (0, 0, 0, 0)
        var (r2, g2, b2, a2): (CGFloat, CGFloat, CGFloat, CGFloat) = (0, 0, 0, 0)
        a.getRed(&r1, green: &g1, blue: &b1, alpha: &a1)
        b.getRed(&r2, green: &g2, blue: &b2, alpha: &a2)
        let t = CGFloat(min(max(amount, 0), 1))
        return Color(red: Double(r1 + (r2 - r1) * t), green: Double(g1 + (g2 - g1) * t),
                     blue: Double(b1 + (b2 - b1) * t), opacity: Double(a1 + (a2 - a1) * t))
    }
}
