//
//  VoixeIndicatorView.swift
//  Voixe
//
//  Soft-edged rounded triangle as the voice presence mark, inspired by the
//  ai-elements Persona "obsidian" variant. Replaces the procedural ray field
//  with an organic shape that:
//    - has rounded corners (no sharp triangle points),
//    - is filled with the Voixe purple→blue gradient that slowly rotates,
//    - sits behind a soft pink/blue halo that fades into the canvas,
//    - has an inner top-left highlight giving it a glassy 3D feel,
//    - audio-reacts via scale (breathes wider when speaking) and rotation rate.
//
//  States (.hidden / .idle / .recording / .transcribing / .prewarming / .refining)
//  drive: gradient stops, glow colour, rotation rate, scale baseline.
//

import Inject
import SwiftUI
import VoixeCore

// MARK: - Indicator view

struct VoixeIndicatorView: View {
  @ObserveInjection var inject

  enum Status: Equatable {
    case hidden
    case idle
    case recording
    case transcribing
    case prewarming
    case refining
  }

  var status: Status
  var meter: Meter

  // MARK: - Layout

  /// Inner triangle diameter (longest dimension). Onboarding hero call sites
  /// apply a `.scaleEffect(...)` multiplier on top.
  private let baseSize: CGFloat = 26
  private let activeSize: CGFloat = 32

  private var size: CGFloat {
    switch status {
    case .hidden: return baseSize
    case .idle, .prewarming: return baseSize
    case .recording, .transcribing, .refining: return activeSize
    }
  }

  // MARK: - Per-state behaviour

  /// Gradient angle rotation rate (turns / second).
  private var rotationRate: Double {
    switch status {
    case .hidden: return 0
    case .idle, .prewarming: return 0.06
    case .recording: return 0.18
    case .transcribing: return 0.24
    case .refining: return 0.10
    }
  }

  /// Brand-tinted halo behind the triangle. Subtle by design — the triangle
  /// itself carries the colour, the halo just adds presence.
  private var glowColor: Color {
    switch status {
    case .hidden: return .clear
    case .idle, .prewarming: return EnginecyPalette.pink.opacity(0.30)
    case .recording: return EnginecyPalette.pink.opacity(0.50)
    case .transcribing: return EnginecyPalette.blue.opacity(0.45)
    case .refining: return EnginecyPalette.mauve.opacity(0.45)
    }
  }

  /// Halo blur radius. Recording reacts to peak power for a "spike on speech"
  /// cue — never blows out though, multiplier is restrained.
  private var glowRadius: CGFloat {
    switch status {
    case .hidden: return 0
    case .idle, .prewarming: return 14
    case .recording: return 16 + CGFloat(meter.peakPower * 18)
    case .transcribing, .refining: return 18
    }
  }

  /// Audio-reactive scale on top of the base. Recording breathes with the
  /// average power; other states get a gentle synthetic breath.
  private func reactiveScale(time t: Double) -> CGFloat {
    let breath = CGFloat(sin(t * 2.0)) * 0.025 + 1.0 // ±2.5% slow breath
    switch status {
    case .recording:
      let amp = CGFloat(min(0.18, meter.averagePower * 0.6))
      return breath + amp
    case .transcribing, .refining:
      return breath + 0.04
    case .idle, .prewarming:
      return breath
    case .hidden:
      return 0.6
    }
  }

  // MARK: - Body

  var body: some View {
    TimelineView(.animation(minimumInterval: 1.0 / 60.0, paused: status == .hidden)) { context in
      let t = context.date.timeIntervalSinceReferenceDate
      let canvasSize = size * 2.0 // room for the halo
      let triSize = size * 1.05
      let scale = reactiveScale(time: t)
      let gradientAngle = Angle.radians(t * rotationRate * .pi * 2)

      ZStack {
        // Faded outer halo
        SoftTriangle(cornerRadius: 0.45)
          .fill(glowColor)
          .blur(radius: max(8, glowRadius))
          .frame(width: triSize * 1.4, height: triSize * 1.4)
          .opacity(status == .hidden ? 0 : 1)

        // Main triangle with rotating brand gradient
        SoftTriangle(cornerRadius: 0.45)
          .fill(
            AngularGradient(
              colors: [
                EnginecyPalette.pink,
                EnginecyPalette.mauve,
                EnginecyPalette.blue,
                EnginecyPalette.mauve,
                EnginecyPalette.pink,
              ],
              center: .center,
              angle: gradientAngle
            )
          )
          .frame(width: triSize, height: triSize)
          .scaleEffect(scale)
          .shadow(color: glowColor.opacity(0.6), radius: 6, y: 2)

        // Glassy inner highlight — soft white at top-left fading to clear.
        SoftTriangle(cornerRadius: 0.45)
          .fill(
            RadialGradient(
              colors: [Color.white.opacity(0.35), Color.clear],
              center: UnitPoint(x: 0.32, y: 0.22),
              startRadius: 0,
              endRadius: triSize * 0.65
            )
          )
          .frame(width: triSize, height: triSize)
          .scaleEffect(scale)
          .blendMode(.plusLighter)
          .allowsHitTesting(false)
      }
      .frame(width: canvasSize, height: canvasSize)
      .opacity(status == .hidden ? 0 : 1)
      .scaleEffect(status == .hidden ? 0.7 : 1)
      .animation(.spring(response: 0.4, dampingFraction: 0.75), value: status)
    }
    .enableInjection()
  }
}

// MARK: - Shape

/// An equilateral triangle with deeply rounded corners. Drawn via three
/// `addArc(tangent1End:tangent2End:radius:)` calls — each corner is a circular
/// arc tangent to the two edges meeting there. cornerRadius is a fraction of
/// the triangle's circumradius (0 = sharp, ~0.5 = blob).
struct SoftTriangle: Shape {
  /// 0...1 — fraction of circumradius used for the corner arc radius.
  var cornerRadius: CGFloat = 0.4

  func path(in rect: CGRect) -> Path {
    let r = min(rect.width, rect.height) / 2
    let cx = rect.midX
    let cy = rect.midY

    // Pointing-up equilateral triangle: top, bottom-right, bottom-left.
    let p1 = CGPoint(x: cx, y: cy - r)
    let p2 = CGPoint(x: cx + r * 0.866, y: cy + r * 0.5)
    let p3 = CGPoint(x: cx - r * 0.866, y: cy + r * 0.5)

    let cornerR = r * cornerRadius

    var path = Path()
    // Start at the midpoint of the left edge so the first arc has somewhere
    // to start tangent to.
    let startEdge = CGPoint(x: (p3.x + p1.x) / 2, y: (p3.y + p1.y) / 2)
    path.move(to: startEdge)
    path.addArc(tangent1End: p1, tangent2End: p2, radius: cornerR)
    path.addArc(tangent1End: p2, tangent2End: p3, radius: cornerR)
    path.addArc(tangent1End: p3, tangent2End: p1, radius: cornerR)
    path.closeSubpath()
    return path
  }
}

#Preview("Voixe Triangle states") {
  VStack(spacing: 36) {
    HStack(spacing: 36) {
      Group {
        VoixeIndicatorView(status: .idle, meter: .init(averagePower: 0, peakPower: 0))
        VoixeIndicatorView(status: .recording, meter: .init(averagePower: 0.4, peakPower: 0.6))
        VoixeIndicatorView(status: .transcribing, meter: .init(averagePower: 0, peakPower: 0))
        VoixeIndicatorView(status: .refining, meter: .init(averagePower: 0, peakPower: 0))
      }
    }
  }
  .padding(60)
  .background(EnginecyPalette.canvas)
}
