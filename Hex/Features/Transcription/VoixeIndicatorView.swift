//
//  VoixeIndicatorView.swift
//  Voixe
//
//  Voice presence mark — the Voixe brand logo, slowly rotating, faster when
//  the user is talking. Sits behind a soft brand-tinted halo that fades into
//  the dark canvas.
//
//  Composition (back to front):
//    1. Faded outer halo — same circular footprint as the logo, blurred and
//       state-tinted (pink/blue/mauve depending on status).
//    2. The Voixe logo (`VoixeMark` asset) — `Image` resource, rotated each
//       frame and audio-reactive on scale.
//
//  Sizes are tuned for the menu-bar / overlay recording indicator. For hero
//  usage (Onboarding welcome, Refine intro) the call site multiplies via
//  `.scaleEffect(...)` — see OnboardingView.swift.
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

  /// Inner logo diameter. Bumped up vs. the previous orb so the brand mark
  /// reads at a glance instead of feeling like a tiny ornament.
  private let baseSize: CGFloat = 34
  private let activeSize: CGFloat = 42

  private var size: CGFloat {
    switch status {
    case .hidden: return baseSize
    case .idle, .prewarming: return baseSize
    case .recording, .transcribing, .refining: return activeSize
    }
  }

  // MARK: - Per-state behaviour

  /// Logo rotation rate (turns / second). Idle is slow but never zero so the
  /// mark feels alive. Recording accelerates so "talking" is visibly faster.
  /// Transcribing/refining are slower than recording — the work is internal,
  /// the orb shouldn't whirl.
  private var rotationRate: Double {
    switch status {
    case .hidden: return 0
    case .idle, .prewarming: return 0.04   // ~25s per revolution
    case .recording: return 0.18           // ~5.5s per revolution
    case .transcribing: return 0.10        // ~10s per revolution — calm "thinking"
    case .refining: return 0.08            // ~12s per revolution
    }
  }

  /// Brand-tinted halo behind the mark. Subtle by design — the logo carries
  /// the colour, the halo just adds presence against the dark canvas.
  private var glowColor: Color {
    switch status {
    case .hidden: return .clear
    case .idle, .prewarming: return EnginecyPalette.pink.opacity(0.30)
    case .recording: return EnginecyPalette.pink.opacity(0.55)
    case .transcribing: return EnginecyPalette.blue.opacity(0.50)
    case .refining: return EnginecyPalette.mauve.opacity(0.45)
    }
  }

  /// Halo blur radius. Recording reacts to peak power for a "spike on speech"
  /// cue. Lowered overall so the aura hugs the orb instead of bleeding into
  /// surrounding UI.
  private var glowRadius: CGFloat {
    switch status {
    case .hidden: return 0
    case .idle, .prewarming: return 7
    case .recording: return 9 + CGFloat(meter.peakPower * 8)
    case .transcribing, .refining: return 10
    }
  }

  /// Scale on top of the base, gives the mark a gentle breath plus an audio
  /// bump while recording so loud speech visibly grows the orb.
  private func reactiveScale(time t: Double) -> CGFloat {
    let breath = CGFloat(sin(t * 1.6)) * 0.025 + 1.0
    switch status {
    case .recording:
      let amp = CGFloat(min(0.18, meter.averagePower * 0.6))
      return breath + amp
    case .transcribing, .refining:
      return breath + 0.04
    case .idle, .prewarming:
      return breath
    case .hidden:
      return 0.7
    }
  }

  // MARK: - Body

  var body: some View {
    TimelineView(.animation(minimumInterval: 1.0 / 60.0, paused: status == .hidden)) { context in
      let t = context.date.timeIntervalSinceReferenceDate
      let canvasSize = size * 1.8
      let scale = reactiveScale(time: t)
      // State-constant rotation rate keeps angle accumulation simple — a small
      // visual "warp" is hidden under the spring transitions when the user
      // changes status.
      let rotation = Angle.degrees(t * rotationRate * 360)

      ZStack {
        // Faded halo — frame hugs the orb tightly (1.15× the logo) so the
        // glow stops at the rim instead of spreading into surrounding UI.
        Circle()
          .fill(glowColor)
          .blur(radius: max(5, glowRadius))
          .frame(width: size * 1.15, height: size * 1.15)
          .opacity(status == .hidden ? 0 : 1)

        // The Voixe logo, rotating + scaling.
        Image("VoixeMark")
          .resizable()
          .interpolation(.high)
          .scaledToFit()
          .frame(width: size, height: size)
          .rotationEffect(rotation)
          .scaleEffect(scale)
          .shadow(color: glowColor.opacity(0.7), radius: 6, y: 2)
      }
      .frame(width: canvasSize, height: canvasSize)
      .opacity(status == .hidden ? 0 : 1)
      .scaleEffect(status == .hidden ? 0.7 : 1)
      .animation(.spring(response: 0.45, dampingFraction: 0.75), value: status)
    }
    .enableInjection()
  }
}

#Preview("Voixe Logo states") {
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
