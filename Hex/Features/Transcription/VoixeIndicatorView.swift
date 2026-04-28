//
//  VoixeIndicatorView.swift
//  Voixe
//
//  The Enginecy mark, animated, pulsing to your voice.
//  Replaces the old capsule-style status indicator with a circular orb that
//  combines (1) the brand SVG, (2) two counter-rotating brand-gradient rings,
//  and (3) an outer glow that intensifies with the audio meter.
//

import Inject
import SwiftUI
import VoixeCore

struct VoixeIndicatorView: View {
  @ObserveInjection var inject

  enum Status: Equatable {
    case hidden
    case idle           // hotkey held / armed but not yet recording
    case recording
    case transcribing
    case prewarming
    case refining
  }

  var status: Status
  var meter: Meter

  // MARK: - Geometry

  private let baseSize: CGFloat = 36
  private let activeSize: CGFloat = 44

  private var size: CGFloat {
    switch status {
    case .hidden: return baseSize
    case .idle, .prewarming: return baseSize
    case .recording, .transcribing, .refining: return activeSize
    }
  }

  // MARK: - Audio-reactive scale (kept tight so the orb breathes, doesn't bounce)

  private var meterScale: CGFloat {
    switch status {
    case .recording:
      return 1 + CGFloat(min(0.25, meter.averagePower * 0.6))
    case .transcribing, .refining:
      return 1.04
    case .idle, .prewarming:
      return 1
    case .hidden:
      return 0.8
    }
  }

  // MARK: - Colors per status

  private var glowColor: Color {
    switch status {
    case .hidden: return .clear
    case .idle, .prewarming: return EnginecyPalette.blue.opacity(0.4)
    case .recording: return EnginecyPalette.pink.opacity(0.6)
    case .transcribing: return EnginecyPalette.blue.opacity(0.6)
    case .refining: return EnginecyPalette.mauve.opacity(0.6)
    }
  }

  private var glowRadius: CGFloat {
    switch status {
    case .hidden: return 0
    case .idle, .prewarming: return 8
    case .recording: return 8 + CGFloat(meter.peakPower * 24)
    case .transcribing, .refining: return 14
    }
  }

  // MARK: - Animations

  @State private var ringRotation: Double = 0
  @State private var idleBreath: CGFloat = 1.0

  var body: some View {
    ZStack {
      // Glow halo
      Circle()
        .fill(glowColor)
        .blur(radius: max(8, glowRadius))
        .frame(width: size * 1.6, height: size * 1.6)
        .opacity(status == .hidden ? 0 : 1)

      // Outer rotating ring
      ringStroke(width: 2, opacity: 0.85, scale: 1.18)
        .rotationEffect(.degrees(ringRotation))

      // Inner counter-rotating ring
      ringStroke(width: 1.5, opacity: 0.55, scale: 1.06)
        .rotationEffect(.degrees(-ringRotation * 0.6))

      // Brand mark
      Image("VoixeMark")
        .resizable()
        .interpolation(.high)
        .scaledToFit()
        .frame(width: size * 0.78, height: size * 0.78)
        .saturation(status == .hidden ? 0 : 1)
        .opacity(status == .hidden ? 0 : 1)
        .scaleEffect(meterScale * idleBreath)
        .shadow(color: glowColor.opacity(0.5), radius: 6)
    }
    .frame(width: size * 1.6, height: size * 1.6)
    .opacity(status == .hidden ? 0 : 1)
    .scaleEffect(status == .hidden ? 0.6 : 1)
    .animation(.spring(response: 0.45, dampingFraction: 0.7), value: status)
    .animation(.easeOut(duration: 0.2), value: meter)
    .onAppear { startRingAnimation() }
    .task(id: status) { await startBreathing() }
    .enableInjection()
  }

  // MARK: - Subviews

  @ViewBuilder
  private func ringStroke(width: CGFloat, opacity: Double, scale: CGFloat) -> some View {
    Circle()
      .strokeBorder(
        EnginecyPalette.ring(angle: .degrees(0)),
        lineWidth: width
      )
      .opacity(opacity)
      .frame(width: size * scale, height: size * scale)
      .blendMode(.plusLighter)
      .opacity(status == .hidden ? 0 : 1)
  }

  // MARK: - Animation drivers

  private func startRingAnimation() {
    withAnimation(.linear(duration: 9).repeatForever(autoreverses: false)) {
      ringRotation = 360
    }
  }

  @MainActor
  private func startBreathing() async {
    guard status == .idle || status == .prewarming || status == .transcribing || status == .refining else {
      idleBreath = 1
      return
    }
    while !Task.isCancelled, status == .idle || status == .prewarming || status == .transcribing || status == .refining {
      withAnimation(.easeInOut(duration: 1.6)) { idleBreath = 1.06 }
      try? await Task.sleep(for: .seconds(1.6))
      withAnimation(.easeInOut(duration: 1.6)) { idleBreath = 1.0 }
      try? await Task.sleep(for: .seconds(1.6))
    }
  }
}

#Preview("Voixe Indicator") {
  VStack(spacing: 32) {
    HStack(spacing: 32) {
      Group {
        VoixeIndicatorView(status: .idle, meter: .init(averagePower: 0, peakPower: 0))
        VoixeIndicatorView(status: .recording, meter: .init(averagePower: 0.35, peakPower: 0.55))
        VoixeIndicatorView(status: .transcribing, meter: .init(averagePower: 0, peakPower: 0))
        VoixeIndicatorView(status: .refining, meter: .init(averagePower: 0, peakPower: 0))
      }
    }
  }
  .padding(60)
  .background(EnginecyPalette.canvas)
}
