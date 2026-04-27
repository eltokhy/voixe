import ComposableArchitecture
import VoixeCore
import Inject
import SwiftUI

struct OnboardingView: View {
  @ObserveInjection var inject
  @Bindable var store: StoreOf<AppFeature>
  @State private var step: Step = .welcome

  enum Step: Int, CaseIterable {
    case welcome, permissions, refine

    var title: String {
      switch self {
      case .welcome: return "Welcome to Voixe"
      case .permissions: return "Grant permissions"
      case .refine: return "Refine your dictation"
      }
    }

    var stepNumber: Int { rawValue + 1 }
    var totalSteps: Int { Step.allCases.count }
  }

  var body: some View {
    ZStack {
      EnginecyPalette.canvas.ignoresSafeArea()

      VStack(spacing: 0) {
        header
        content
        footer
      }
    }
    .frame(width: 600, height: 540)
    .preferredColorScheme(.dark)
    .enableInjection()
  }

  private var header: some View {
    HStack {
      Text("Step \(step.stepNumber) of \(step.totalSteps)")
        .font(.caption)
        .foregroundStyle(.white.opacity(0.45))
      Spacer()
      Button(action: complete) {
        Text("Skip")
          .font(.caption)
          .foregroundStyle(.white.opacity(0.6))
          .padding(.horizontal, 14)
          .padding(.vertical, 6)
          .background(
            Capsule().stroke(Color.white.opacity(0.12), lineWidth: 1)
          )
      }
      .buttonStyle(.plain)
    }
    .padding(.horizontal, 24)
    .padding(.vertical, 18)
  }

  private var content: some View {
    Group {
      switch step {
      case .welcome: WelcomeStep(store: store)
      case .permissions: PermissionsStep(store: store)
      case .refine: RefineStep(store: store)
      }
    }
    .padding(.horizontal, 32)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
  }

  private var footer: some View {
    HStack(spacing: 12) {
      if let prev = Step(rawValue: step.rawValue - 1) {
        Button(action: { withAnimation(.easeInOut(duration: 0.25)) { step = prev } }) {
          Text("Back")
            .font(.callout)
            .foregroundStyle(.white.opacity(0.7))
            .padding(.horizontal, 18)
            .padding(.vertical, 10)
            .background(Capsule().fill(EnginecyPalette.surface))
            .overlay(Capsule().stroke(EnginecyPalette.stroke, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .keyboardShortcut(.cancelAction)
      } else {
        Spacer().frame(width: 60)
      }

      Spacer()

      if let next = Step(rawValue: step.rawValue + 1) {
        primaryButton("Continue") {
          withAnimation(.easeInOut(duration: 0.25)) { step = next }
        }
        .keyboardShortcut(.defaultAction)
      } else {
        primaryButton("Done", action: complete)
          .keyboardShortcut(.defaultAction)
      }
    }
    .padding(24)
  }

  @ViewBuilder
  private func primaryButton(_ title: String, action: @escaping () -> Void) -> some View {
    Button(action: action) {
      Text(title)
        .font(.callout.weight(.semibold))
        .foregroundStyle(.white)
        .padding(.horizontal, 22)
        .padding(.vertical, 11)
        .background(
          Capsule().fill(EnginecyPalette.accent)
        )
        .shadow(color: EnginecyPalette.pink.opacity(0.4), radius: 12, y: 4)
    }
    .buttonStyle(.plain)
  }

  private func complete() {
    store.send(.completeFirstRun)
  }
}

// MARK: - Welcome step

private struct WelcomeStep: View {
  @Bindable var store: StoreOf<AppFeature>

  var body: some View {
    VStack(spacing: 24) {
      Spacer()

      VoixeIndicatorView(
        status: .idle,
        meter: .init(averagePower: 0, peakPower: 0)
      )
      .scaleEffect(2.4)
      .frame(height: 140)

      VStack(spacing: 8) {
        Text("Welcome to Voixe")
          .font(.title2.weight(.semibold))
          .foregroundStyle(.white)
        Text("Hold a hotkey, speak, and your transcript pastes wherever you're typing — fully on-device.")
          .font(.subheadline)
          .foregroundStyle(.white.opacity(0.6))
          .multilineTextAlignment(.center)
          .frame(maxWidth: 380)
      }

      VStack(alignment: .leading, spacing: 10) {
        bulletRow(
          icon: "mic.circle",
          title: "On-device transcription",
          body: "Whisper or Parakeet runs entirely on your Mac. No audio leaves the machine."
        )
        bulletRow(
          icon: "wand.and.stars",
          title: "Refine cleanup, optional",
          body: "A local LLM strips fillers, fixes backtracks, and executes spoken commands."
        )
        bulletRow(
          icon: "sparkles",
          title: "Free, made by Enginecy",
          body: "A free freebie from enginecy.com — a creative agency that builds for the people we want to work with."
        )
      }
      .padding(.horizontal, 8)

      Spacer()
    }
  }

  private func bulletRow(icon: String, title: String, body: String) -> some View {
    HStack(alignment: .top, spacing: 12) {
      Image(systemName: icon)
        .foregroundStyle(EnginecyPalette.accent)
        .frame(width: 22)
        .font(.system(size: 14, weight: .medium))
      VStack(alignment: .leading, spacing: 2) {
        Text(title).font(.subheadline.weight(.semibold)).foregroundStyle(.white)
        Text(body).font(.caption).foregroundStyle(.white.opacity(0.55))
      }
    }
  }
}

// MARK: - Permissions step

private struct PermissionsStep: View {
  @Bindable var store: StoreOf<AppFeature>

  var body: some View {
    VStack(spacing: 18) {
      Spacer().frame(height: 4)

      Text("Voixe needs three permissions to work.")
        .font(.title3.weight(.semibold))
        .foregroundStyle(.white)
      Text("Grant them now or later in System Settings → Privacy & Security.")
        .font(.subheadline)
        .foregroundStyle(.white.opacity(0.55))
        .multilineTextAlignment(.center)

      VStack(spacing: 10) {
        permissionRow(
          title: "Microphone",
          body: "Records your voice for transcription.",
          status: store.microphonePermission,
          action: { store.send(.requestMicrophone) }
        )
        permissionRow(
          title: "Accessibility",
          body: "Pastes the transcript into the active app.",
          status: store.accessibilityPermission,
          action: { store.send(.requestAccessibility) }
        )
        permissionRow(
          title: "Input Monitoring",
          body: "Listens for the global hotkey across all apps.",
          status: store.inputMonitoringPermission,
          action: { store.send(.requestInputMonitoring) }
        )
      }
      .padding(.top, 8)

      Spacer()
    }
    .onAppear { store.send(.checkPermissions) }
  }

  private func permissionRow(
    title: String,
    body: String,
    status: PermissionStatus,
    action: @escaping () -> Void
  ) -> some View {
    HStack(spacing: 14) {
      ZStack {
        Circle().fill(EnginecyPalette.surfaceRaised)
          .frame(width: 36, height: 36)
        statusIcon(for: status)
      }
      VStack(alignment: .leading, spacing: 2) {
        Text(title).font(.subheadline.weight(.semibold)).foregroundStyle(.white)
        Text(body).font(.caption).foregroundStyle(.white.opacity(0.55))
      }
      Spacer()
      if status != .granted {
        Button(action: action) {
          Text("Grant")
            .font(.caption.weight(.semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 14)
            .padding(.vertical, 6)
            .background(Capsule().fill(EnginecyPalette.accent))
        }
        .buttonStyle(.plain)
      } else {
        Text("Granted")
          .font(.caption.weight(.semibold))
          .foregroundStyle(EnginecyPalette.mint)
      }
    }
    .padding(14)
    .background(
      RoundedRectangle(cornerRadius: 14).fill(EnginecyPalette.surface)
    )
    .overlay(
      RoundedRectangle(cornerRadius: 14).stroke(EnginecyPalette.stroke, lineWidth: 1)
    )
  }

  @ViewBuilder
  private func statusIcon(for status: PermissionStatus) -> some View {
    switch status {
    case .granted:
      Image(systemName: "checkmark").foregroundStyle(EnginecyPalette.mint)
    case .denied:
      Image(systemName: "xmark").foregroundStyle(EnginecyPalette.pink)
    case .notDetermined:
      Image(systemName: "circle.dashed").foregroundStyle(.white.opacity(0.4))
    }
  }
}

// MARK: - Refine step

private struct RefineStep: View {
  @Bindable var store: StoreOf<AppFeature>

  private var refineEnabled: Bool { store.hexSettings.refine.isEnabled }
  private var bootstrapInProgress: Bool { store.settings.refineModelDownload.isDownloading }
  private var bootstrapProgress: Double { store.settings.refineModelDownload.downloadProgress }

  var body: some View {
    VStack(spacing: 20) {
      Spacer().frame(height: 4)

      VoixeIndicatorView(
        status: refineEnabled ? .refining : .idle,
        meter: .init(averagePower: 0, peakPower: 0)
      )
      .scaleEffect(1.6)
      .frame(height: 80)

      Text("Refine cleans up your dictation")
        .font(.title3.weight(.semibold))
        .foregroundStyle(.white)
      Text("A local LLM removes fillers, adds punctuation, executes commands like \u{201C}make it bulleted,\u{201D} and matches tone to the active app. Fully on-device.")
        .font(.subheadline)
        .foregroundStyle(.white.opacity(0.6))
        .multilineTextAlignment(.center)
        .frame(maxWidth: 420)
        .fixedSize(horizontal: false, vertical: true)

      VStack(alignment: .leading, spacing: 6) {
        Text("Default model: Qwen 2.5 1.5B Instruct (4-bit, ~900 MB)")
          .font(.caption.weight(.semibold))
          .foregroundStyle(.white.opacity(0.85))
        Text("Downloads in the background. You can change models any time in Settings → Refine.")
          .font(.caption)
          .foregroundStyle(.white.opacity(0.5))
      }
      .frame(maxWidth: .infinity, alignment: .leading)
      .padding(14)
      .background(RoundedRectangle(cornerRadius: 12).fill(EnginecyPalette.surface))

      if bootstrapInProgress {
        VStack(alignment: .leading, spacing: 6) {
          Text("Downloading… \(Int(bootstrapProgress * 100))%")
            .font(.caption)
            .foregroundStyle(.white.opacity(0.7))
          ProgressView(value: bootstrapProgress)
            .tint(EnginecyPalette.pink)
        }
      }

      if refineEnabled {
        Label("Refine enabled", systemImage: "checkmark.circle.fill")
          .foregroundStyle(EnginecyPalette.mint)
          .font(.callout.weight(.semibold))
      } else {
        Button(action: { store.send(.enableRefineFromOnboarding) }) {
          Text("Enable Refine + download default model")
            .font(.callout.weight(.semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 22)
            .padding(.vertical, 12)
            .background(Capsule().fill(EnginecyPalette.accent))
            .shadow(color: EnginecyPalette.pink.opacity(0.4), radius: 14, y: 4)
        }
        .buttonStyle(.plain)
      }

      Spacer()
    }
  }
}
