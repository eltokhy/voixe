//
//  LLMRefinementClient.swift
//  Hex
//
//  Sends a raw transcript to a local LLM endpoint (Ollama-compatible) for
//  cleanup, command execution, and app-context tone matching.
//

import Dependencies
import DependenciesMacros
import Foundation
import VoixeCore

private let refineLogger = VoixeLog.refine

public enum RefineError: Error, LocalizedError, Sendable {
  case invalidEndpoint(String)
  case network(Error)
  case badStatus(Int)
  case emptyResponse
  case decodingFailed(Error)
  case timedOut
  case bundledModelMissing(String)
  case bundledRuntimeUnavailable
  case bundled(String)

  public var errorDescription: String? {
    switch self {
    case let .invalidEndpoint(endpoint):
      return "Invalid refine endpoint: \(endpoint)"
    case let .network(error):
      return "Refine request failed: \(error.localizedDescription)"
    case let .badStatus(code):
      return "Refine endpoint returned HTTP \(code)"
    case .emptyResponse:
      return "Refine endpoint returned an empty response"
    case let .decodingFailed(error):
      return "Failed to decode refine response: \(error.localizedDescription)"
    case .timedOut:
      return "Refine request timed out"
    case let .bundledModelMissing(repo):
      return "Refine model \(repo) is not downloaded yet. Open Settings → Refine to download it."
    case .bundledRuntimeUnavailable:
      return "Bundled refine runtime is not compiled into this build. Add the mlx-swift-examples Swift package in Xcode (File → Add Package Dependencies → https://github.com/ml-explore/mlx-swift-examples), link MLXLLM and MLXLMCommon to the Hex target, and rebuild."
    case let .bundled(message):
      return "Bundled refine failed: \(message)"
    }
  }
}

@DependencyClient
struct LLMRefinementClient {
  /// Run the refine pass over `text` using the given settings and app context.
  /// Throws `RefineError` on any failure so the caller can decide whether to fall back.
  var refine: @Sendable (
    _ text: String,
    _ appName: String?,
    _ bundleID: String?,
    _ settings: RefineSettings
  ) async throws -> String

  /// List models available at the given Ollama endpoint (`GET /api/tags`).
  var listModels: @Sendable (_ endpoint: String) async throws -> [String]

  /// Quick reachability check for the settings "Test connection" button.
  var ping: @Sendable (_ endpoint: String) async -> Bool = { _ in false }
}

extension LLMRefinementClient: DependencyKey {
  static var liveValue: Self {
    Self(
      refine: { text, appName, bundleID, settings in
        switch settings.runtimeMode {
        case .ollama:
          return try await LLMRefinementClientLive.refine(
            text: text,
            appName: appName,
            bundleID: bundleID,
            settings: settings
          )
        case .bundled:
          return try await BundledRefineDispatcher.refine(
            text: text,
            appName: appName,
            bundleID: bundleID,
            settings: settings
          )
        }
      },
      listModels: { endpoint in
        try await LLMRefinementClientLive.listModels(endpoint: endpoint)
      },
      ping: { endpoint in
        await LLMRefinementClientLive.ping(endpoint: endpoint)
      }
    )
  }

  static var testValue = Self()
}

// MARK: - Bundled dispatcher

/// Bridges the runtime-mode router to MLXRefineRunner. Resolves the local model
/// directory via the download client (no compile-time MLX dependency required).
private enum BundledRefineDispatcher {
  static func refine(
    text: String,
    appName: String?,
    bundleID: String?,
    settings: RefineSettings
  ) async throws -> String {
    guard mlxRuntimeAvailable else {
      refineLogger.error("Bundled refine requested but MLX runtime is not compiled in")
      throw RefineError.bundledRuntimeUnavailable
    }

    @Dependency(\.refineModelDownload) var refineModelDownload
    let model = refineModelDownload.curatedModels()
      .first(where: { $0.huggingFaceRepo == settings.bundledModelID })
      ?? RefineModel(
        displayName: settings.bundledModelID,
        huggingFaceRepo: settings.bundledModelID,
        accuracyStars: 3,
        speedStars: 3,
        storageSize: "—",
        sizeBytes: 0
      )

    guard let modelDirectory = refineModelDownload.localURL(model) else {
      throw RefineError.bundledModelMissing(settings.bundledModelID)
    }

    let systemPrompt = RefineSettings.renderSystemPrompt(
      settings.systemPrompt,
      appName: appName,
      bundleID: bundleID
    )

    refineLogger.info("Bundled refine call to model \(settings.bundledModelID, privacy: .public) appName=\(appName ?? "unknown", privacy: .public)")
    refineLogger.debug("Bundled refine input: \(text, privacy: .private)")

    do {
      let output = try await MLXRefineRunner.shared.generate(
        modelDirectory: modelDirectory,
        systemPrompt: systemPrompt,
        userPrompt: text,
        temperature: settings.temperature
      )
      let cleaned = output.trimmingCharacters(in: .whitespacesAndNewlines)
      guard !cleaned.isEmpty else { throw RefineError.emptyResponse }
      refineLogger.debug("Bundled refine output: \(cleaned, privacy: .private)")
      return cleaned
    } catch let error as MLXRefineError {
      switch error {
      case .bundledRuntimeUnavailable:
        throw RefineError.bundledRuntimeUnavailable
      case .modelDirectoryMissing:
        throw RefineError.bundledModelMissing(settings.bundledModelID)
      case let .loadFailed(message), let .generationFailed(message):
        throw RefineError.bundled(message)
      }
    } catch {
      throw RefineError.bundled(error.localizedDescription)
    }
  }
}

extension DependencyValues {
  var llmRefinement: LLMRefinementClient {
    get { self[LLMRefinementClient.self] }
    set { self[LLMRefinementClient.self] = newValue }
  }
}

// MARK: - Live implementation

private enum LLMRefinementClientLive {
  static func refine(
    text: String,
    appName: String?,
    bundleID: String?,
    settings: RefineSettings
  ) async throws -> String {
    guard var components = URLComponents(string: settings.endpoint) else {
      throw RefineError.invalidEndpoint(settings.endpoint)
    }
    let trimmedPath = components.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
    components.path = trimmedPath.isEmpty ? "/api/chat" : "/\(trimmedPath)/api/chat"
    guard let url = components.url else {
      throw RefineError.invalidEndpoint(settings.endpoint)
    }

    let systemPrompt = RefineSettings.renderSystemPrompt(
      settings.systemPrompt,
      appName: appName,
      bundleID: bundleID
    )

    let payload = OllamaChatRequest(
      model: settings.model,
      stream: false,
      messages: [
        .init(role: "system", content: systemPrompt),
        .init(role: "user", content: text)
      ],
      options: .init(temperature: settings.temperature)
    )

    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.timeoutInterval = settings.timeoutSeconds
    do {
      request.httpBody = try JSONEncoder().encode(payload)
    } catch {
      throw RefineError.decodingFailed(error)
    }

    refineLogger.info("Refine request to \(url.absoluteString, privacy: .public) model=\(settings.model, privacy: .public) appName=\(appName ?? "unknown", privacy: .public)")
    refineLogger.debug("Refine input: \(text, privacy: .private)")

    let data: Data
    let response: URLResponse
    do {
      (data, response) = try await URLSession.shared.data(for: request)
    } catch let error as URLError where error.code == .timedOut {
      throw RefineError.timedOut
    } catch {
      throw RefineError.network(error)
    }

    if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
      throw RefineError.badStatus(http.statusCode)
    }

    let decoded: OllamaChatResponse
    do {
      decoded = try JSONDecoder().decode(OllamaChatResponse.self, from: data)
    } catch {
      throw RefineError.decodingFailed(error)
    }

    let cleaned = stripArtifacts(decoded.message?.content ?? "")
    guard !cleaned.isEmpty else {
      throw RefineError.emptyResponse
    }

    refineLogger.debug("Refine output: \(cleaned, privacy: .private)")
    return cleaned
  }

  static func listModels(endpoint: String) async throws -> [String] {
    guard var components = URLComponents(string: endpoint) else {
      throw RefineError.invalidEndpoint(endpoint)
    }
    let trimmedPath = components.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
    components.path = trimmedPath.isEmpty ? "/api/tags" : "/\(trimmedPath)/api/tags"
    guard let url = components.url else {
      throw RefineError.invalidEndpoint(endpoint)
    }

    var request = URLRequest(url: url)
    request.timeoutInterval = 4
    let (data, response): (Data, URLResponse)
    do {
      (data, response) = try await URLSession.shared.data(for: request)
    } catch {
      throw RefineError.network(error)
    }
    if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
      throw RefineError.badStatus(http.statusCode)
    }
    do {
      let decoded = try JSONDecoder().decode(OllamaTagsResponse.self, from: data)
      return decoded.models.map(\.name)
    } catch {
      throw RefineError.decodingFailed(error)
    }
  }

  static func ping(endpoint: String) async -> Bool {
    guard let models = try? await listModels(endpoint: endpoint) else { return false }
    return !models.isEmpty
  }

  /// Remove things Ollama sometimes wraps around short replies: code fences, leading/trailing quotes, whitespace.
  private static func stripArtifacts(_ text: String) -> String {
    var output = text.trimmingCharacters(in: .whitespacesAndNewlines)
    if output.hasPrefix("```") {
      if let range = output.range(of: "\n") {
        output = String(output[range.upperBound...])
      }
      if output.hasSuffix("```") {
        output = String(output.dropLast(3))
      }
      output = output.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    if output.count >= 2 {
      let first = output.first!
      let last = output.last!
      if (first == "\"" && last == "\"") || (first == "'" && last == "'") {
        output = String(output.dropFirst().dropLast())
      }
    }
    return output.trimmingCharacters(in: .whitespacesAndNewlines)
  }
}

// MARK: - Ollama wire format

private struct OllamaChatRequest: Encodable {
  struct Message: Encodable {
    let role: String
    let content: String
  }
  struct Options: Encodable {
    let temperature: Double
  }
  let model: String
  let stream: Bool
  let messages: [Message]
  let options: Options
}

private struct OllamaChatResponse: Decodable {
  struct Message: Decodable {
    let role: String?
    let content: String?
  }
  let message: Message?
}

private struct OllamaTagsResponse: Decodable {
  struct ModelEntry: Decodable {
    let name: String
  }
  let models: [ModelEntry]
}
