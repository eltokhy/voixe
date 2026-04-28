//
//  EnginecyPalette.swift
//  Voixe
//
//  Centralised brand colors + gradients for Voixe.
//  Two-color brand: purple (#7701e5) → blue (#0f76ef).
//  (Voixe's own palette, distinct from Enginecy's full radial spectrum.)
//

import SwiftUI

enum EnginecyPalette {
  // MARK: - Brand colors (Voixe two-color gradient)

  /// Voixe brand purple — `#7701e5`. Aliased to `pink` for backward compat
  /// with view code that already references `EnginecyPalette.pink` (warm hue
  /// at the start of the gradient).
  static let pink     = Color(red: 0x77 / 255, green: 0x01 / 255, blue: 0xE5 / 255)

  /// Voixe brand blue — `#0f76ef` (cool hue at the end of the gradient).
  static let blue     = Color(red: 0x0F / 255, green: 0x76 / 255, blue: 0xEF / 255)

  /// Mid-point between purple and blue, useful as a third stop for the
  /// `refining` indicator state where we want something distinguishable from
  /// pure recording (purple) or pure transcribing (blue).
  static let mauve    = Color(red: 0x43 / 255, green: 0x3B / 255, blue: 0xEA / 255)

  /// Success green — used for "Granted" badges and the copy-confirmation
  /// checkmark. Kept outside the brand gradient deliberately.
  static let mint     = Color(red: 0x2A / 255, green: 0xD7 / 255, blue: 0x9F / 255)

  // Aliases retained from the previous Enginecy spectrum so any straggler
  // call sites compile. Map them onto the closest two-color stop.
  static let orange   = pink
  static let sage     = blue

  // MARK: - Surfaces

  static let canvas        = Color(white: 0.04)
  static let surface       = Color(white: 0.08)
  static let surfaceRaised = Color(white: 0.12)
  static let stroke        = Color.white.opacity(0.10)

  // MARK: - Gradients

  /// Full brand band, top-leading to bottom-trailing.
  static let spectrum = LinearGradient(
    colors: [pink, mauve, blue],
    startPoint: .topLeading,
    endPoint: .bottomTrailing
  )

  /// Hero CTA gradient — purple → blue.
  static let accent = LinearGradient(
    colors: [pink, blue],
    startPoint: .leading,
    endPoint: .trailing
  )

  /// Angular variant for the orb's rotating rings. Loops the two stops twice
  /// so the rotation feels continuous instead of seam-y.
  static func ring(angle: Angle = .zero) -> AngularGradient {
    AngularGradient(
      colors: [pink, blue, pink, blue, pink],
      center: .center,
      angle: angle
    )
  }
}

// MARK: - Reusable styles

/// Primary CTA — purple → blue capsule with a soft purple glow.
struct BrandPillButtonStyle: ButtonStyle {
  var size: Size = .regular

  enum Size { case small, regular }

  func makeBody(configuration: Configuration) -> some View {
    let horizontal: CGFloat = size == .small ? 14 : 22
    let vertical: CGFloat = size == .small ? 7 : 11
    return configuration.label
      .font((size == .small ? Font.caption : Font.callout).weight(.semibold))
      .foregroundStyle(.white)
      .padding(.horizontal, horizontal)
      .padding(.vertical, vertical)
      .background(Capsule().fill(EnginecyPalette.accent))
      .shadow(color: EnginecyPalette.pink.opacity(configuration.isPressed ? 0.2 : 0.4),
              radius: configuration.isPressed ? 4 : 12, y: 4)
      .scaleEffect(configuration.isPressed ? 0.97 : 1)
      .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
  }
}

/// Secondary action — outlined capsule on the surface color.
struct BrandSecondaryButtonStyle: ButtonStyle {
  func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .font(.callout)
      .foregroundStyle(.white.opacity(configuration.isPressed ? 0.6 : 0.8))
      .padding(.horizontal, 16)
      .padding(.vertical, 8)
      .background(Capsule().fill(EnginecyPalette.surface))
      .overlay(Capsule().stroke(EnginecyPalette.stroke, lineWidth: 1))
      .scaleEffect(configuration.isPressed ? 0.97 : 1)
      .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
  }
}

extension View {
  /// Brand card: rounded surface with a subtle stroke.
  func brandCard(cornerRadius: CGFloat = 14) -> some View {
    self
      .background(RoundedRectangle(cornerRadius: cornerRadius).fill(EnginecyPalette.surface))
      .overlay(RoundedRectangle(cornerRadius: cornerRadius).stroke(EnginecyPalette.stroke, lineWidth: 1))
  }
}
