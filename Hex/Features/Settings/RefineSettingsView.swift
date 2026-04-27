import ComposableArchitecture
import VoixeCore
import Inject
import SwiftUI

struct RefineSettingsView: View {
  @ObserveInjection var inject
  @Bindable var store: StoreOf<SettingsFeature>

  var body: some View {
    Section {
      Label {
        Toggle("Enable Refine", isOn: Binding(
          get: { store.hexSettings.refine.isEnabled },
          set: { store.send(.setRefineEnabled($0)) }
        ))
        Text("Run each transcription through a local LLM to clean up fillers, execute spoken commands, and match the tone of the active app.")
          .settingsCaption()
      } icon: {
        Image(systemName: "wand.and.stars")
      }

      if store.hexSettings.refine.isEnabled {
        runtimeRow
        if store.hexSettings.refine.runtimeMode == .bundled {
          if !mlxRuntimeAvailable {
            mlxUnavailableNotice
          }
          if shouldShowBootstrapBanner {
            bootstrapBanner
          }
          bundledModelsRow
        } else {
          endpointRow
          modelRow
        }
        temperatureRow
        fallbackRow
        systemPromptRow
      }
    } header: {
      Text("Refine (Local LLM)")
    } footer: {
      if store.hexSettings.refine.isEnabled {
        Text(footerText)
          .font(.footnote)
          .foregroundColor(.secondary)
      }
    }
    .enableInjection()
  }

  private var footerText: String {
    switch store.hexSettings.refine.runtimeMode {
    case .bundled:
      return "Bundled mode runs the refine model directly inside Hex on Apple Silicon. Nothing leaves your machine. The system prompt adapts to the frontmost app at paste time."
    case .ollama:
      return "Ollama mode talks to a local Ollama server. Nothing leaves your machine. Useful if you already run larger models like Gemma 4."
    }
  }

  private var runtimeRow: some View {
    Label {
      VStack(alignment: .leading, spacing: 6) {
        Picker("Runtime", selection: Binding(
          get: { store.hexSettings.refine.runtimeMode },
          set: { store.send(.setRefineRuntimeMode($0)) }
        )) {
          Text("Bundled (recommended)").tag(RefineRuntimeMode.bundled)
          Text("Ollama (advanced)").tag(RefineRuntimeMode.ollama)
        }
        .pickerStyle(.segmented)

        Text(store.hexSettings.refine.runtimeMode == .bundled
             ? "Pick a downloadable model below. Voixe runs it on-device with no external services."
             : "Voixe sends each transcription to a local Ollama server you manage.")
          .settingsCaption()
      }
    } icon: {
      Image(systemName: "circle.grid.2x2")
    }
  }

  private var mlxUnavailableNotice: some View {
    Label {
      VStack(alignment: .leading, spacing: 4) {
        Text("MLX runtime not compiled in")
          .font(.subheadline.weight(.semibold))
        Text("To enable bundled inference, in Xcode: File → Add Package Dependencies → https://github.com/ml-explore/mlx-swift-examples, and link the **MLXLLM** and **MLXLMCommon** products to the Hex target. Until then, switch to Ollama or download a model below — Hex will surface a clear error when refining.")
          .settingsCaption()
      }
    } icon: {
      Image(systemName: "exclamationmark.triangle.fill")
        .foregroundStyle(.orange)
    }
  }

  private var bundledModelsRow: some View {
    Label {
      RefineCuratedList(store: store.scope(state: \.refineModelDownload, action: \.refineModelDownload))
    } icon: {
      Image(systemName: "square.and.arrow.down")
    }
  }

  private var shouldShowBootstrapBanner: Bool {
    let download = store.refineModelDownload
    return download.isDownloading
      && !store.hexSettings.hasCompletedRefineBootstrap
      && download.downloadingRepo == RefineModelCatalog.defaultModelID
  }

  private var bootstrapBanner: some View {
    Label {
      VStack(alignment: .leading, spacing: 6) {
        Text("Setting up Refine…")
          .font(.subheadline.weight(.semibold))
        ProgressView(value: store.refineModelDownload.downloadProgress)
          .progressViewStyle(.linear)
          .tint(EnginecyPalette.pink)
        Text("Downloading the default refine model (\(Int(store.refineModelDownload.downloadProgress * 100))%). You can keep using Voixe while this finishes — Refine activates as soon as it's done.")
          .settingsCaption()
      }
    } icon: {
      Image(systemName: "icloud.and.arrow.down")
        .foregroundStyle(EnginecyPalette.pink)
    }
  }

  private var endpointRow: some View {
    Label {
      VStack(alignment: .leading, spacing: 8) {
        HStack {
          Text("Endpoint")
          Spacer()
          TextField("http://localhost:11434", text: Binding(
            get: { store.hexSettings.refine.endpoint },
            set: { store.send(.setRefineEndpoint($0)) }
          ))
          .textFieldStyle(.roundedBorder)
          .frame(maxWidth: 240)
          .autocorrectionDisabled()
        }

        HStack(spacing: 8) {
          Button {
            store.send(.testRefineConnection)
          } label: {
            if store.refineConnectionState == .testing {
              ProgressView().controlSize(.small)
            } else {
              Text("Test connection")
            }
          }
          .disabled(store.refineConnectionState == .testing)

          switch store.refineConnectionState {
          case .unknown:
            EmptyView()
          case .testing:
            Text("Testing…").settingsCaption()
          case .ok:
            Label("Connected", systemImage: "checkmark.circle.fill")
              .foregroundStyle(.green)
              .font(.caption)
          case .failed:
            Label("Unreachable", systemImage: "exclamationmark.triangle.fill")
              .foregroundStyle(.orange)
              .font(.caption)
          }

          Spacer()
        }
      }
    } icon: {
      Image(systemName: "network")
    }
  }

  private var modelRow: some View {
    Label {
      VStack(alignment: .leading, spacing: 8) {
        HStack {
          Text("Model")
          Spacer()
          if store.availableRefineModels.isEmpty {
            TextField("gemma4:e4b", text: Binding(
              get: { store.hexSettings.refine.model },
              set: { store.send(.setRefineModel($0)) }
            ))
            .textFieldStyle(.roundedBorder)
            .frame(maxWidth: 240)
            .autocorrectionDisabled()
          } else {
            Picker("", selection: Binding(
              get: { store.hexSettings.refine.model },
              set: { store.send(.setRefineModel($0)) }
            )) {
              ForEach(store.availableRefineModels, id: \.self) { model in
                Text(model).tag(model)
              }
              if !store.availableRefineModels.contains(store.hexSettings.refine.model) {
                Text(store.hexSettings.refine.model).tag(store.hexSettings.refine.model)
              }
            }
            .pickerStyle(.menu)
            .frame(maxWidth: 240)
          }
        }

        HStack(spacing: 8) {
          Button("Reload models") {
            store.send(.loadRefineModels)
          }
          .buttonStyle(.borderless)
          .font(.caption)
          if let error = store.refineModelsError {
            Text(error)
              .settingsCaption()
              .lineLimit(1)
              .truncationMode(.middle)
          }
          Spacer()
        }
      }
    } icon: {
      Image(systemName: "cpu")
    }
  }

  private var temperatureRow: some View {
    Label {
      HStack {
        Text("Temperature")
        Slider(
          value: Binding(
            get: { store.hexSettings.refine.temperature },
            set: { store.send(.setRefineTemperature($0)) }
          ),
          in: 0.0...1.0,
          step: 0.05
        )
        Text(String(format: "%.2f", store.hexSettings.refine.temperature))
          .monospacedDigit()
          .frame(width: 44, alignment: .trailing)
      }
    } icon: {
      Image(systemName: "thermometer.medium")
    }
  }

  private var fallbackRow: some View {
    Label {
      Toggle("Fall back to raw transcript on error", isOn: Binding(
        get: { store.hexSettings.refine.fallbackOnError },
        set: { store.send(.setRefineFallbackOnError($0)) }
      ))
      Text("If the refine call fails or times out, paste the unrefined transcript instead of showing an error.")
        .settingsCaption()
    } icon: {
      Image(systemName: "arrow.uturn.backward.circle")
    }
  }

  private var systemPromptRow: some View {
    Label {
      VStack(alignment: .leading, spacing: 8) {
        HStack {
          Text("System Prompt")
          Spacer()
          Button("Restore default") {
            store.send(.resetRefineSystemPrompt)
          }
          .buttonStyle(.borderless)
          .font(.caption)
        }

        TextEditor(text: Binding(
          get: { store.hexSettings.refine.systemPrompt },
          set: { store.send(.setRefineSystemPrompt($0)) }
        ))
        .font(.system(.body, design: .monospaced))
        .frame(minHeight: 140, maxHeight: 220)
        .overlay(
          RoundedRectangle(cornerRadius: 6)
            .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
        )

        Text("Supports {appName} and {bundleID} placeholders, substituted with the frontmost app at refine time.")
          .settingsCaption()
      }
    } icon: {
      Image(systemName: "text.bubble")
    }
  }
}
