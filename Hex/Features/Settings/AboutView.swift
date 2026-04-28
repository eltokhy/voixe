import ComposableArchitecture
import Inject
import SwiftUI
import Sparkle

struct AboutView: View {
  @ObserveInjection var inject
  @Bindable var store: StoreOf<SettingsFeature>
  @State var viewModel = CheckForUpdatesViewModel.shared
  @State private var showingChangelog = false

  private var versionString: String {
    Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "Unknown"
  }

  var body: some View {
    ZStack {
      EnginecyPalette.canvas.ignoresSafeArea()

      ScrollView {
        VStack(spacing: 18) {
          hero

          aboutCard {
            row(icon: "info.circle", title: "Version", trailing: AnyView(
              HStack(spacing: 12) {
                Text(versionString).foregroundStyle(.white.opacity(0.7))
                Button("Check for Updates") { viewModel.checkForUpdates() }
                  .buttonStyle(BrandSecondaryButtonStyle())
              }
            ))
            divider
            row(icon: "doc.text", title: "Changelog", trailing: AnyView(
              Button("Show Changelog") { showingChangelog.toggle() }
                .buttonStyle(BrandSecondaryButtonStyle())
                .sheet(isPresented: $showingChangelog) {
                  ChangelogView()
                }
            ))
          }

          aboutCard {
            row(icon: "apple.terminal.on.rectangle", title: "Voixe is open source", trailing: AnyView(
              brandLink("View on GitHub", url: "https://github.com/eltokhy/voixe")
            ))
            divider
            row(icon: "sparkles", title: "Made by Enginecy", trailing: AnyView(
              brandLink("Visit Enginecy", url: "https://enginecy.com")
            ))
          }

          Spacer(minLength: 24)
        }
        .padding(24)
        .frame(maxWidth: 540)
      }
      .scrollContentBackground(.hidden)
    }
    .preferredColorScheme(.dark)
    .enableInjection()
  }

  // MARK: - Hero

  private var hero: some View {
    VStack(spacing: 14) {
      Image("VoixeMark")
        .resizable()
        .scaledToFit()
        .frame(width: 96, height: 96)
        .shadow(color: EnginecyPalette.pink.opacity(0.4), radius: 24)
      VStack(spacing: 6) {
        Text("Made by Enginecy")
          .eyebrow()
        Text("Voixe")
          .font(.system(size: 44, weight: .semibold))
          .tracking(-1)
          .foregroundStyle(.white)
      }
      Text("Voice → text on macOS. On-device. Free.")
        .font(.callout)
        .foregroundStyle(.white.opacity(0.6))
    }
    .padding(.top, 12)
  }

  // MARK: - Card primitives

  @ViewBuilder
  private func aboutCard<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
    VStack(spacing: 0) {
      content()
    }
    .padding(.vertical, 4)
    .frame(maxWidth: .infinity)
    .brandCard()
  }

  private var divider: some View {
    Rectangle()
      .fill(EnginecyPalette.stroke)
      .frame(height: 1)
      .padding(.horizontal, 14)
  }

  private func row(icon: String, title: String, trailing: AnyView) -> some View {
    HStack(spacing: 12) {
      Image(systemName: icon)
        .foregroundStyle(EnginecyPalette.pink)
        .frame(width: 22)
      Text(title)
        .font(.subheadline.weight(.medium))
        .foregroundStyle(.white)
      Spacer()
      trailing
    }
    .padding(.horizontal, 14)
    .padding(.vertical, 12)
  }

  private func brandLink(_ label: String, url: String) -> some View {
    Link(destination: URL(string: url)!) {
      Text(label)
        .font(.callout.weight(.semibold))
        .foregroundStyle(EnginecyPalette.pink)
    }
    .buttonStyle(.plain)
  }
}
