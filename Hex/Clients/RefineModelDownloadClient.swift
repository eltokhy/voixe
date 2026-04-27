//
//  RefineModelDownloadClient.swift
//  Hex
//
//  Downloads MLX refine models from HuggingFace into the Hex app-support folder.
//  Talks directly to the public HF "tree" + "resolve" endpoints over URLSession —
//  no swift-transformers dependency required.
//

import Dependencies
import DependenciesMacros
import Foundation
import VoixeCore

private let refineDownloadLogger = VoixeLog.refine

@DependencyClient
struct RefineModelDownloadClient {
  /// Curated catalog (parsed from refine-models.json, falling back to the embedded list).
  var curatedModels: @Sendable () -> [RefineModel] = { RefineModelCatalog.default }

  /// Local URL of a downloaded model directory, or `nil` if not present.
  var localURL: @Sendable (_ model: RefineModel) -> URL? = { _ in nil }

  /// Download a model. `progress.fractionCompleted` is updated as files arrive.
  /// Returns the local model directory.
  var download: @Sendable (
    _ model: RefineModel,
    _ progress: @escaping @Sendable (Progress) -> Void
  ) async throws -> URL

  /// Delete a downloaded model from disk.
  var delete: @Sendable (_ model: RefineModel) async throws -> Void

  /// Open the refine-models directory in Finder.
  var revealInFinder: @Sendable (_ model: RefineModel?) -> Void = { _ in }
}

extension RefineModelDownloadClient: DependencyKey {
  static var liveValue: Self {
    let live = RefineModelDownloadLive()
    return Self(
      curatedModels: { live.curatedModels() },
      localURL: { live.localURL(for: $0) },
      download: { try await live.download(model: $0, progress: $1) },
      delete: { try await live.delete(model: $0) },
      revealInFinder: { live.revealInFinder(model: $0) }
    )
  }

  static var testValue = Self()
}

extension DependencyValues {
  var refineModelDownload: RefineModelDownloadClient {
    get { self[RefineModelDownloadClient.self] }
    set { self[RefineModelDownloadClient.self] = newValue }
  }
}

// MARK: - Live implementation

import AppKit

private final class RefineModelDownloadLive: @unchecked Sendable {
  private let session: URLSession = {
    let config = URLSessionConfiguration.default
    config.timeoutIntervalForRequest = 30
    config.timeoutIntervalForResource = 3600
    return URLSession(configuration: config)
  }()

  func curatedModels() -> [RefineModel] {
    if let url = Bundle.main.url(forResource: "refine-models", withExtension: "json")
      ?? Bundle.main.url(forResource: "refine-models", withExtension: "json", subdirectory: "Data") {
      do {
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode([RefineModel].self, from: data)
      } catch {
        refineDownloadLogger.error("Failed to decode refine-models.json: \(error.localizedDescription, privacy: .public)")
      }
    }
    return RefineModelCatalog.default
  }

  func localURL(for model: RefineModel) -> URL? {
    guard let baseURL = try? URL.hexRefineModelsDirectory else { return nil }
    let modelDir = baseURL.appendingPathComponent(model.directorySlug, isDirectory: true)
    let configFile = modelDir.appendingPathComponent("config.json")
    return FileManager.default.fileExists(atPath: configFile.path) ? modelDir : nil
  }

  func download(
    model: RefineModel,
    progress progressHandler: @escaping @Sendable (Progress) -> Void
  ) async throws -> URL {
    let baseURL = try URL.hexRefineModelsDirectory
    let modelDir = baseURL.appendingPathComponent(model.directorySlug, isDirectory: true)
    try FileManager.default.createDirectory(at: modelDir, withIntermediateDirectories: true)

    refineDownloadLogger.info("Refine model download starting: \(model.huggingFaceRepo, privacy: .public)")

    let files = try await listFiles(repo: model.huggingFaceRepo)
    let interesting = files.filter { name in
      name.hasSuffix(".safetensors")
        || name.hasSuffix(".json")
        || name.hasSuffix(".txt")
        || name.hasSuffix(".tiktoken")
        || name == "tokenizer.model"
    }

    guard !interesting.isEmpty else {
      throw RefineDownloadError.noFiles(model.huggingFaceRepo)
    }

    let totalProgress = Progress(totalUnitCount: model.sizeBytes > 0 ? model.sizeBytes : Int64(interesting.count) * 10_000_000)
    progressHandler(totalProgress)

    var bytesSoFar: Int64 = 0
    for file in interesting {
      let target = modelDir.appendingPathComponent(file)
      try FileManager.default.createDirectory(
        at: target.deletingLastPathComponent(),
        withIntermediateDirectories: true
      )
      let downloaded = try await downloadFile(
        repo: model.huggingFaceRepo,
        path: file,
        to: target,
        baseProgress: totalProgress,
        bytesAlreadyDone: bytesSoFar,
        progressHandler: progressHandler
      )
      bytesSoFar += downloaded
    }

    if totalProgress.totalUnitCount > 0 {
      totalProgress.completedUnitCount = totalProgress.totalUnitCount
    }
    progressHandler(totalProgress)

    refineDownloadLogger.info("Refine model download complete: \(model.huggingFaceRepo, privacy: .public)")
    return modelDir
  }

  func delete(model: RefineModel) async throws {
    let baseURL = try URL.hexRefineModelsDirectory
    let modelDir = baseURL.appendingPathComponent(model.directorySlug, isDirectory: true)
    if FileManager.default.fileExists(atPath: modelDir.path) {
      try FileManager.default.removeItem(at: modelDir)
    }
  }

  func revealInFinder(model: RefineModel?) {
    guard let baseURL = try? URL.hexRefineModelsDirectory else { return }
    let target: URL
    if let model {
      target = baseURL.appendingPathComponent(model.directorySlug, isDirectory: true)
    } else {
      target = baseURL
    }
    let path = FileManager.default.fileExists(atPath: target.path) ? target.path : baseURL.path
    NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: path)
  }

  // MARK: - HuggingFace Hub

  private func listFiles(repo: String) async throws -> [String] {
    guard let url = URL(string: "https://huggingface.co/api/models/\(repo)/tree/main?recursive=1") else {
      throw RefineDownloadError.invalidRepo(repo)
    }
    let (data, response) = try await session.data(from: url)
    if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
      throw RefineDownloadError.badStatus(http.statusCode)
    }
    let entries = try JSONDecoder().decode([HFTreeEntry].self, from: data)
    return entries.filter { $0.type == "file" }.map(\.path)
  }

  private func downloadFile(
    repo: String,
    path: String,
    to target: URL,
    baseProgress: Progress,
    bytesAlreadyDone: Int64,
    progressHandler: @escaping @Sendable (Progress) -> Void
  ) async throws -> Int64 {
    if FileManager.default.fileExists(atPath: target.path) {
      let size = (try? FileManager.default.attributesOfItem(atPath: target.path)[.size] as? Int64) ?? 0
      return size
    }
    let escapedPath = path.split(separator: "/").map {
      String($0).addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? String($0)
    }.joined(separator: "/")
    guard let url = URL(string: "https://huggingface.co/\(repo)/resolve/main/\(escapedPath)") else {
      throw RefineDownloadError.invalidRepo(repo)
    }

    let (bytes, response) = try await session.bytes(from: url)
    if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
      throw RefineDownloadError.badStatus(http.statusCode)
    }

    FileManager.default.createFile(atPath: target.path, contents: nil)
    let handle = try FileHandle(forWritingTo: target)
    defer { try? handle.close() }

    let expectedFileSize = response.expectedContentLength
    var written: Int64 = 0
    var buffer = Data()
    buffer.reserveCapacity(64 * 1024)
    let flushThreshold = 64 * 1024
    var lastReport: Date = .distantPast

    for try await byte in bytes {
      buffer.append(byte)
      written += 1
      if buffer.count >= flushThreshold {
        try handle.write(contentsOf: buffer)
        buffer.removeAll(keepingCapacity: true)
        let now = Date()
        if now.timeIntervalSince(lastReport) > 0.1 {
          updateProgress(
            baseProgress: baseProgress,
            bytesAlreadyDone: bytesAlreadyDone,
            currentFileWritten: written,
            currentFileExpected: expectedFileSize,
            handler: progressHandler
          )
          lastReport = now
        }
      }
    }
    if !buffer.isEmpty {
      try handle.write(contentsOf: buffer)
    }
    updateProgress(
      baseProgress: baseProgress,
      bytesAlreadyDone: bytesAlreadyDone,
      currentFileWritten: written,
      currentFileExpected: expectedFileSize,
      handler: progressHandler
    )
    return written
  }

  private func updateProgress(
    baseProgress: Progress,
    bytesAlreadyDone: Int64,
    currentFileWritten: Int64,
    currentFileExpected: Int64,
    handler: @escaping @Sendable (Progress) -> Void
  ) {
    let total = baseProgress.totalUnitCount
    if total > 0 {
      let completed = min(total, bytesAlreadyDone + currentFileWritten)
      baseProgress.completedUnitCount = completed
      handler(baseProgress)
    } else {
      handler(baseProgress)
    }
  }
}

// MARK: - Wire types and errors

private struct HFTreeEntry: Decodable {
  let type: String
  let path: String
}

enum RefineDownloadError: Error, LocalizedError {
  case invalidRepo(String)
  case badStatus(Int)
  case noFiles(String)

  var errorDescription: String? {
    switch self {
    case let .invalidRepo(repo):
      return "Invalid model repository: \(repo)"
    case let .badStatus(code):
      return "HuggingFace returned HTTP \(code)"
    case let .noFiles(repo):
      return "No model files found in \(repo)"
    }
  }
}
