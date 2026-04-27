//
//  MLXRefineRunner.swift
//  Hex
//
//  In-process MLX-Swift inference for the bundled refine path.
//
//  Compiles in two modes via `canImport(MLXLLM)`:
//  - WITHOUT the MLX-Swift packages: this file builds, every call returns
//    `bundledRuntimeUnavailable`, and the user is directed to the Settings tab
//    where the message tells them to add the SPM dependency.
//  - WITH `mlx-swift-examples` added (Xcode → File → Add Package Dependencies →
//    https://github.com/ml-explore/mlx-swift-examples, link products `MLXLLM`
//    and `MLXLMCommon` to the Hex target): the runner loads a downloaded model
//    container and generates refined text for each transcription.
//

import Foundation
import VoixeCore

#if canImport(MLXLLM) && canImport(MLXLMCommon)
import MLXLLM
import MLXLMCommon
#endif

private let mlxLogger = VoixeLog.refine

/// Errors specific to the bundled-runtime path.
public enum MLXRefineError: Error, LocalizedError, Sendable {
  case bundledRuntimeUnavailable
  case modelDirectoryMissing(URL)
  case loadFailed(String)
  case generationFailed(String)

  public var errorDescription: String? {
    switch self {
    case .bundledRuntimeUnavailable:
      return "MLX runtime is not compiled into this build. Add the mlx-swift-examples Swift package in Xcode (File → Add Package Dependencies → https://github.com/ml-explore/mlx-swift-examples) and link the MLXLLM and MLXLMCommon products to the Hex target."
    case let .modelDirectoryMissing(url):
      return "Refine model directory not found at \(url.path). Download the model from Settings → Refine."
    case let .loadFailed(message):
      return "Failed to load refine model: \(message)"
    case let .generationFailed(message):
      return "Refine generation failed: \(message)"
    }
  }
}

/// Whether the bundled MLX runtime is compiled into this build.
public var mlxRuntimeAvailable: Bool {
  #if canImport(MLXLLM) && canImport(MLXLMCommon)
  return true
  #else
  return false
  #endif
}

/// Long-lived inference session. Loads the model lazily on first refine call and
/// keeps the container in memory until the user changes models or quits the app.
actor MLXRefineRunner {
  static let shared = MLXRefineRunner()

  private var loadedModelDirectory: URL?

  #if canImport(MLXLLM) && canImport(MLXLMCommon)
  private var container: ModelContainer?
  #endif

  /// Generate refined text. Loads the model the first time it's called for a given directory.
  func generate(
    modelDirectory: URL,
    systemPrompt: String,
    userPrompt: String,
    temperature: Double,
    maxTokens: Int = 512
  ) async throws -> String {
    #if canImport(MLXLLM) && canImport(MLXLMCommon)
    guard FileManager.default.fileExists(atPath: modelDirectory.path) else {
      throw MLXRefineError.modelDirectoryMissing(modelDirectory)
    }
    if loadedModelDirectory != modelDirectory || container == nil {
      try await loadContainer(at: modelDirectory)
    }
    guard let container else {
      throw MLXRefineError.loadFailed("ModelContainer is nil after load")
    }

    do {
      let parameters = GenerateParameters(temperature: Float(temperature))
      let result = try await container.perform { context -> String in
        let userMessage = Chat.Message.user(userPrompt)
        let systemMessage = Chat.Message.system(systemPrompt)
        let userInput = UserInput(chat: [systemMessage, userMessage])
        let lmInput = try await context.processor.prepare(input: userInput)
        var output = ""
        let stream = try MLXLMCommon.generate(
          input: lmInput,
          parameters: parameters,
          context: context
        )
        for await piece in stream {
          if case let .chunk(text) = piece {
            output += text
          }
          if output.count >= maxTokens * 8 { break }
        }
        return output
      }
      return result.trimmingCharacters(in: .whitespacesAndNewlines)
    } catch let error as MLXRefineError {
      throw error
    } catch {
      throw MLXRefineError.generationFailed(error.localizedDescription)
    }
    #else
    _ = modelDirectory
    _ = systemPrompt
    _ = userPrompt
    _ = temperature
    _ = maxTokens
    throw MLXRefineError.bundledRuntimeUnavailable
    #endif
  }

  /// Drop the loaded container to free memory.
  func unload() async {
    #if canImport(MLXLLM) && canImport(MLXLMCommon)
    container = nil
    #endif
    loadedModelDirectory = nil
  }

  #if canImport(MLXLLM) && canImport(MLXLMCommon)
  private func loadContainer(at directory: URL) async throws {
    mlxLogger.info("Loading MLX refine model from \(directory.path, privacy: .public)")
    do {
      let configuration = ModelConfiguration(directory: directory)
      let factory = LLMModelFactory.shared
      container = try await factory.loadContainer(configuration: configuration)
      loadedModelDirectory = directory
      mlxLogger.info("MLX refine model loaded")
    } catch {
      throw MLXRefineError.loadFailed(error.localizedDescription)
    }
  }
  #endif
}
