//
//  VoixeIndicatorView.swift
//  Voixe
//
//  Procedural voice orb. The Voixe rays are drawn directly in SwiftUI Canvas
//  on a per-frame TimelineView so each ray can:
//    - rotate continuously around the centre,
//    - breathe in/out on its own phase offset (organic motion, not strobe),
//    - extend audio-reactively when recording (peak power → ray length),
//    - colour-shift along the brand purple→blue gradient as the angle sweeps.
//
//  States:
//    .hidden      → fully invisible
//    .idle        → soft slow breathing (purple glow)
//    .recording   → rays extend with the live audio meter (purple glow)
//    .prewarming  → similar to idle but sligtly faster
//    .transcribing→ faster rotation, energetic motion (blue glow)
//    .refining    → mid-state, longer rays, mauve glow
//

import Inject
import SwiftUI
import VoixeCore

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

  private let baseSize: CGFloat = 44
  private let activeSize: CGFloat = 56

  private var size: CGFloat {
    switch status {
    case .hidden: return baseSize
    case .idle, .prewarming: return baseSize
    case .recording, .transcribing, .refining: return activeSize
    }
  }

  // MARK: - Per-state behaviour

  /// Rotation rate in turns per second (full revolutions / second).
  private var rotationRate: Double {
    switch status {
    case .hidden: return 0
    case .idle, .prewarming: return 0.04
    case .recording: return 0.12
    case .transcribing: return 0.18
    case .refining: return 0.10
    }
  }

  /// Glow colour that surrounds the orb. Kept restrained — the rays carry the
  /// brand colour, the halo is just a soft shadow of presence.
  private var glowColor: Color {
    switch status {
    case .hidden: return .clear
    case .idle, .prewarming: return EnginecyPalette.pink.opacity(0.18)
    case .recording: return EnginecyPalette.pink.opacity(0.32)
    case .transcribing: return EnginecyPalette.blue.opacity(0.28)
    case .refining: return EnginecyPalette.mauve.opacity(0.28)
    }
  }

  /// Glow blur radius — recording still reacts to peak power for a "spike on
  /// speech" cue, but the multiplier is dialed down so the halo never bloats.
  private var glowRadius: CGFloat {
    switch status {
    case .hidden: return 0
    case .idle, .prewarming: return 6
    case .recording: return 8 + CGFloat(meter.peakPower * 12)
    case .transcribing, .refining: return 10
    }
  }

  /// Audio amplitude that drives ray length. Recording uses live mic; other
  /// states use a synthetic gentle wave so the orb still feels alive.
  private var amplitude: CGFloat {
    switch status {
    case .recording:
      return CGFloat(min(1.0, meter.averagePower * 1.6))
    case .refining, .transcribing:
      return 0.35
    case .idle, .prewarming:
      return 0.18
    case .hidden:
      return 0
    }
  }

  private let rayCount: Int = 64

  // MARK: - Body

  var body: some View {
    TimelineView(.animation(minimumInterval: 1.0 / 60.0, paused: status == .hidden)) { context in
      let elapsed = context.date.timeIntervalSinceReferenceDate
      let canvasSize = size * 1.8 // give the glow + ray extension breathing room

      ZStack {
        // Ambient halo — tighter footprint than the canvas (1.05× the orb itself,
        // not the full ray-extension area) so the glow hugs the orb instead of
        // bleeding into surrounding UI.
        Circle()
          .fill(glowColor)
          .blur(radius: max(6, glowRadius))
          .frame(width: size * 1.05, height: size * 1.05)
          .opacity(status == .hidden ? 0 : 1)

        // Procedural ray field
        Canvas { ctx, drawSize in
          drawRays(into: ctx, size: drawSize, time: elapsed)
        }
        .frame(width: canvasSize, height: canvasSize)
        .blendMode(.plusLighter) // additive — rays brighten the halo where they cross it
      }
      .frame(width: canvasSize, height: canvasSize)
      .opacity(status == .hidden ? 0 : 1)
      .scaleEffect(status == .hidden ? 0.6 : 1)
      .animation(.spring(response: 0.45, dampingFraction: 0.7), value: status)
    }
    .enableInjection()
  }

  // MARK: - Drawing

  private func drawRays(into ctx: GraphicsContext, size canvasSize: CGSize, time t: Double) {
    let centre = CGPoint(x: canvasSize.width / 2, y: canvasSize.height / 2)
    let radius = min(canvasSize.width, canvasSize.height) * 0.5

    // Ring geometry
    let innerR = radius * 0.30
    let baseOuterR = radius * 0.50
    let maxExtension = radius * 0.42

    let baseAngle = t * rotationRate * .pi * 2

    for i in 0..<rayCount {
      let normalized = Double(i) / Double(rayCount)
      let angle = baseAngle + normalized * .pi * 2

      // Per-ray phase offset → independent breathing, not a synchronised strobe.
      let phase = normalized * .pi * 2 * 3 // 3 wave cycles around the ring
      let wave = (sin(t * 1.6 + phase) + 1) / 2 // 0...1
      let lengthFactor = 0.35 + wave * 0.35 + Double(amplitude) * 0.6
      let outerR = baseOuterR + maxExtension * CGFloat(min(1.0, lengthFactor))

      let inner = CGPoint(
        x: centre.x + CGFloat(cos(angle)) * innerR,
        y: centre.y + CGFloat(sin(angle)) * innerR
      )
      let outer = CGPoint(
        x: centre.x + CGFloat(cos(angle)) * outerR,
        y: centre.y + CGFloat(sin(angle)) * outerR
      )

      // Colour position along the purple→blue gradient.
      // Use the ray's vertical component so the gradient feels like a top-to-bottom
      // wash that rotates with the ring.
      let colourPosition = (sin(angle - .pi / 2) + 1) / 2 // 0 (top) → 1 (bottom)
      let rayColor = mixColor(EnginecyPalette.pink, EnginecyPalette.blue, t: colourPosition)

      // Ray opacity dips slightly with amplitude wave so the rim shimmers.
      let opacity = 0.55 + wave * 0.35

      var path = Path()
      path.move(to: inner)
      path.addLine(to: outer)
      ctx.stroke(
        path,
        with: .color(rayColor.opacity(opacity)),
        style: StrokeStyle(lineWidth: 2.0, lineCap: .round)
      )
    }
  }

  /// Linearly interpolate two SwiftUI Colors in sRGB space.
  private func mixColor(_ a: Color, _ b: Color, t: Double) -> Color {
    let aN = NSColor(a).usingColorSpace(.deviceRGB) ?? .black
    let bN = NSColor(b).usingColorSpace(.deviceRGB) ?? .black
    let clamped = max(0, min(1, t))
    let r = aN.redComponent + (bN.redComponent - aN.redComponent) * clamped
    let g = aN.greenComponent + (bN.greenComponent - aN.greenComponent) * clamped
    let bl = aN.blueComponent + (bN.blueComponent - aN.blueComponent) * clamped
    return Color(red: Double(r), green: Double(g), blue: Double(bl))
  }
}

#Preview("Voixe Orb states") {
  VStack(spacing: 36) {
    HStack(spacing: 36) {
      Group {
        VoixeIndicatorView(status: .idle, meter: .init(averagePower: 0, peakPower: 0))
        VoixeIndicatorView(status: .recording, meter: .init(averagePower: 0.5, peakPower: 0.7))
        VoixeIndicatorView(status: .transcribing, meter: .init(averagePower: 0, peakPower: 0))
        VoixeIndicatorView(status: .refining, meter: .init(averagePower: 0, peakPower: 0))
      }
    }
  }
  .padding(60)
  .background(EnginecyPalette.canvas)
}
