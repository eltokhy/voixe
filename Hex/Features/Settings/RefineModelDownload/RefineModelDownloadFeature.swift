//
//  RefineModelDownloadFeature.swift
//  Hex
//
//  TCA reducer for the curated refine model picker. Mirrors ModelDownloadFeature
//  but with a single, simple list (no "show more"), and routes downloads/deletes
//  to RefineModelDownloadClient instead of TranscriptionClient.
//

import AppKit
import ComposableArchitecture
import Dependencies
import Foundation
import VoixeCore

@Reducer
public struct RefineModelDownloadFeature {
  @ObservableState
  public struct State: Equatable {
    @Shared(.hexSettings) var hexSettings: VoixeSettings

    public var models: [RefineModel] = []
    public var downloadedRepos: Set<String> = []

    public var isDownloading: Bool = false
    public var downloadingRepo: String?
    public var downloadProgress: Double = 0
    public var downloadError: String?
    public var activeDownloadID: UUID?

    public init() {}

    public var selectedRepo: String { hexSettings.refine.bundledModelID }
  }

  public enum Action {
    case task
    case selectModel(String)
    case downloadModel(String)
    case downloadProgress(repo: String, fraction: Double)
    case downloadCompleted(repo: String, Result<URL, Error>)
    case cancelDownload
    case deleteModel(String)
    case revealInFinder(String?)
    case modelsLoaded([RefineModel], downloaded: Set<String>)
    /// First-time auto-trigger: if no model is downloaded yet and the user
    /// hasn't been bootstrapped, kick off the default download.
    case ensureBootstrap
  }

  @Dependency(\.refineModelDownload) var refineModelDownload

  public init() {}

  public var body: some ReducerOf<Self> {
    Reduce { state, action in
      switch action {
      case .task:
        return .run { [refineModelDownload] send in
          let models = refineModelDownload.curatedModels()
          let downloaded = Set(models.compactMap { model -> String? in
            refineModelDownload.localURL(model) != nil ? model.huggingFaceRepo : nil
          })
          await send(.modelsLoaded(models, downloaded: downloaded))
        }

      case let .modelsLoaded(models, downloaded):
        state.models = models
        state.downloadedRepos = downloaded
        // If the persisted model id isn't in the curated list, leave selection alone
        // (the user can re-pick from the curated list); otherwise no-op.
        return .none

      case let .selectModel(repo):
        state.$hexSettings.withLock { $0.refine.bundledModelID = repo }
        return .none

      case let .downloadModel(repo):
        guard let model = state.models.first(where: { $0.huggingFaceRepo == repo }) else { return .none }
        state.isDownloading = true
        state.downloadingRepo = repo
        state.downloadProgress = 0
        state.downloadError = nil
        let downloadID = UUID()
        state.activeDownloadID = downloadID
        return .run { [refineModelDownload] send in
          do {
            _ = try await refineModelDownload.download(model) { progress in
              Task { await send(.downloadProgress(repo: repo, fraction: progress.fractionCompleted)) }
            }
            await send(.downloadCompleted(repo: repo, .success(URL(fileURLWithPath: "/"))))
          } catch {
            await send(.downloadCompleted(repo: repo, .failure(error)))
          }
        }
        .cancellable(id: downloadID)

      case let .downloadProgress(repo, fraction):
        guard state.downloadingRepo == repo else { return .none }
        state.downloadProgress = fraction
        return .none

      case let .downloadCompleted(repo, result):
        state.isDownloading = false
        state.downloadingRepo = nil
        state.activeDownloadID = nil
        switch result {
        case .success:
          state.downloadedRepos.insert(repo)
          state.downloadError = nil
          state.downloadProgress = 1
          // First successful refine model download flips the bootstrap flag so
          // future toggles of Refine on/off don't re-trigger an auto-download.
          state.$hexSettings.withLock { $0.hasCompletedRefineBootstrap = true }
        case let .failure(error):
          state.downloadError = error.localizedDescription
          state.downloadProgress = 0
        }
        return .none

      case .cancelDownload:
        guard let id = state.activeDownloadID else { return .none }
        state.isDownloading = false
        state.downloadingRepo = nil
        state.activeDownloadID = nil
        state.downloadProgress = 0
        return .cancel(id: id)

      case let .deleteModel(repo):
        guard let model = state.models.first(where: { $0.huggingFaceRepo == repo }) else { return .none }
        state.downloadedRepos.remove(repo)
        return .run { [refineModelDownload] send in
          try? await refineModelDownload.delete(model)
          await send(.task)
        }

      case let .revealInFinder(repo):
        let model = repo.flatMap { id in state.models.first(where: { $0.huggingFaceRepo == id }) }
        return .run { [refineModelDownload] _ in
          refineModelDownload.revealInFinder(model)
        }

      case .ensureBootstrap:
        // Run once: only when no refine model is on disk and we haven't been bootstrapped before.
        guard state.hexSettings.refine.runtimeMode == .bundled else { return .none }
        guard !state.hexSettings.hasCompletedRefineBootstrap else { return .none }
        guard state.downloadedRepos.isEmpty else { return .none }
        guard !state.isDownloading else { return .none }
        let defaultID = RefineModelCatalog.defaultModelID
        state.$hexSettings.withLock { $0.refine.bundledModelID = defaultID }
        return .send(.downloadModel(defaultID))
      }
    }
  }
}
