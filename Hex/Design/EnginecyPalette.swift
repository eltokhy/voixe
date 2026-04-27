//
//  EnginecyPalette.swift
//  Voixe
//
//  Centralised brand colors + gradients for Voixe.
//  Sourced from the Enginecy icon SVG's master radial gradient.
//

import SwiftUI

enum EnginecyPalette {
  // MARK: - Brand stops (Enginecy radial gradient, in order)

  static let orange   = Color(red: 0xF2 / 255, green: 0x80 / 255, blue: 0x06 / 255)
  static let pink     = Color(red: 0xFD / 255, green: 0x15 / 255, blue: 0x68 / 255)
  static let mauve    = Color(red: 0x9B / 255, green: 0x2C / 255, blue: 0x56 / 255)
  static let sage     = Color(red: 0x4D / 255, green: 0x8E / 255, blue: 0x79 / 255)
  static let mint     = Color(red: 0x00 / 255, green: 0xE8 / 255, blue: 0x9E / 255)
  static let blue     = Color(red: 0x04 / 255, green: 0x60 / 255, blue: 0xD9 / 255)

  // MARK: - Surfaces

  static let canvas        = Color(white: 0.04)
  static let surface       = Color(white: 0.08)
  static let surfaceRaised = Color(white: 0.12)
  static let stroke        = Color.white.opacity(0.10)

  // MARK: - Gradients

  /// Full brand spectrum, top-leading to bottom-trailing. Use sparingly for accents.
  static let spectrum = LinearGradient(
    colors: [orange, pink, mauve, sage, mint, blue],
    startPoint: .topLeading,
    endPoint: .bottomTrailing
  )

  /// Compact accent for buttons / progress fills (Enginecy's hero pink → blue arc).
  static let accent = LinearGradient(
    colors: [pink, mauve, blue],
    startPoint: .leading,
    endPoint: .trailing
  )

  /// Conic version, used for the orb's rotating rings.
  static func ring(angle: Angle = .zero) -> AngularGradient {
    AngularGradient(
      colors: [orange, pink, mauve, sage, mint, blue, orange],
      center: .center,
      angle: angle
    )
  }
}

// MARK: - Reusable styles

/// Primary CTA — pink → blue capsule with a soft pink shadow halo.
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
  /// Brand card: rounded-16 dark surface with a subtle stroke.
  func brandCard(cornerRadius: CGFloat = 14) -> some View {
    self
      .background(RoundedRectangle(cornerRadius: cornerRadius).fill(EnginecyPalette.surface))
      .overlay(RoundedRectangle(cornerRadius: cornerRadius).stroke(EnginecyPalette.stroke, lineWidth: 1))
  }
}
