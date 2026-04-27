import XCTest
@testable import VoixeCore

final class RefineSettingsTests: XCTestCase {
	func testDefaultsAreDisabledAndPointAtLocalOllama() {
		let settings = RefineSettings()
		XCTAssertFalse(settings.isEnabled)
		XCTAssertEqual(settings.runtimeMode, .bundled)
		XCTAssertEqual(settings.bundledModelID, RefineModelCatalog.defaultModelID)
		XCTAssertEqual(settings.endpoint, "http://localhost:11434")
		XCTAssertEqual(settings.model, "gemma4:e4b")
		XCTAssertTrue(settings.fallbackOnError)
		XCTAssertEqual(settings.temperature, 0.2, accuracy: 1e-9)
		XCTAssertGreaterThan(settings.timeoutSeconds, 0)
		XCTAssertFalse(settings.systemPrompt.isEmpty)
	}

	func testRuntimeModeAndBundledModelIDRoundTrip() throws {
		var settings = RefineSettings()
		settings.runtimeMode = .ollama
		settings.bundledModelID = "mlx-community/Qwen2.5-3B-Instruct-4bit"
		let data = try JSONEncoder().encode(settings)
		let decoded = try JSONDecoder().decode(RefineSettings.self, from: data)
		XCTAssertEqual(decoded.runtimeMode, .ollama)
		XCTAssertEqual(decoded.bundledModelID, "mlx-community/Qwen2.5-3B-Instruct-4bit")
		XCTAssertEqual(decoded, settings)
	}

	func testLegacyRefineSettingsDecodeWithoutRuntimeFields() throws {
		// A pre-bundled-runtime payload would only have the v1 keys.
		let payload = """
		{"isEnabled": true, "endpoint": "http://localhost:11434", "model": "gemma4:e4b", "systemPrompt": "x", "temperature": 0.4, "timeoutSeconds": 10, "fallbackOnError": false}
		"""
		guard let data = payload.data(using: .utf8) else {
			XCTFail("Failed to build payload")
			return
		}
		let decoded = try JSONDecoder().decode(RefineSettings.self, from: data)
		XCTAssertTrue(decoded.isEnabled)
		// Missing runtimeMode/bundledModelID fields should fall back to defaults.
		XCTAssertEqual(decoded.runtimeMode, .bundled)
		XCTAssertEqual(decoded.bundledModelID, RefineModelCatalog.defaultModelID)
	}

	func testCatalogContainsFourTiers() {
		let catalog = RefineModelCatalog.default
		XCTAssertEqual(catalog.count, 4)
		XCTAssertEqual(catalog.map(\.huggingFaceRepo).sorted(), [
			"mlx-community/Llama-3.2-1B-Instruct-4bit",
			"mlx-community/Qwen2.5-0.5B-Instruct-4bit",
			"mlx-community/Qwen2.5-1.5B-Instruct-4bit",
			"mlx-community/Qwen2.5-3B-Instruct-4bit"
		])
		// Stars should always be 1...5 and the default model should be a 4-star.
		for entry in catalog {
			XCTAssertGreaterThanOrEqual(entry.accuracyStars, 1)
			XCTAssertLessThanOrEqual(entry.accuracyStars, 5)
			XCTAssertGreaterThanOrEqual(entry.speedStars, 1)
			XCTAssertLessThanOrEqual(entry.speedStars, 5)
		}
		XCTAssertEqual(catalog.first(where: { $0.huggingFaceRepo == RefineModelCatalog.defaultModelID })?.accuracyStars, 4)
	}

	func testNewBootstrapFlagsDefaultToFalseAndRoundTrip() throws {
		let defaults = VoixeSettings()
		XCTAssertFalse(defaults.hasCompletedRefineBootstrap)
		XCTAssertFalse(defaults.hasCompletedFirstRun)

		var modified = defaults
		modified.hasCompletedRefineBootstrap = true
		modified.hasCompletedFirstRun = true
		let data = try JSONEncoder().encode(modified)
		let decoded = try JSONDecoder().decode(VoixeSettings.self, from: data)
		XCTAssertTrue(decoded.hasCompletedRefineBootstrap)
		XCTAssertTrue(decoded.hasCompletedFirstRun)
	}

	func testLegacySettingsDecodeWithoutNewBootstrapFlags() throws {
		let payload = "{\"openOnLogin\":true}"
		guard let data = payload.data(using: .utf8) else {
			XCTFail("Failed to build payload")
			return
		}
		let decoded = try JSONDecoder().decode(VoixeSettings.self, from: data)
		XCTAssertFalse(decoded.hasCompletedRefineBootstrap)
		XCTAssertFalse(decoded.hasCompletedFirstRun)
	}

	func testDirectorySlugIsFilesystemSafe() {
		let model = RefineModel(
			displayName: "X",
			huggingFaceRepo: "mlx-community/Foo-Bar",
			accuracyStars: 3,
			speedStars: 3,
			storageSize: "1 MB",
			sizeBytes: 1
		)
		XCTAssertEqual(model.directorySlug, "mlx-community_Foo-Bar")
		XCTAssertFalse(model.directorySlug.contains("/"))
	}

	func testCodableRoundTripPreservesAllFields() throws {
		let original = RefineSettings(
			isEnabled: true,
			endpoint: "http://localhost:1234",
			model: "gemma3:12b",
			systemPrompt: "custom",
			temperature: 0.7,
			timeoutSeconds: 20,
			fallbackOnError: false
		)
		let data = try JSONEncoder().encode(original)
		let decoded = try JSONDecoder().decode(RefineSettings.self, from: data)
		XCTAssertEqual(original, decoded)
	}

	func testHexSettingsRoundTripIncludesRefine() throws {
		var settings = VoixeSettings()
		settings.refine.isEnabled = true
		settings.refine.model = "gemma3:27b"
		let data = try JSONEncoder().encode(settings)
		let decoded = try JSONDecoder().decode(VoixeSettings.self, from: data)
		XCTAssertEqual(decoded.refine.isEnabled, true)
		XCTAssertEqual(decoded.refine.model, "gemma3:27b")
		XCTAssertEqual(decoded, settings)
	}

	func testLegacySettingsWithoutRefineKeyDecodeToDefaults() throws {
		// Payload mimics a pre-refine settings blob — missing `refine` entirely.
		let payload = "{\"openOnLogin\":true}"
		guard let data = payload.data(using: .utf8) else {
			XCTFail("Failed to build JSON payload")
			return
		}
		let decoded = try JSONDecoder().decode(VoixeSettings.self, from: data)
		XCTAssertEqual(decoded.refine, RefineSettings())
		XCTAssertTrue(decoded.openOnLogin)
	}

	func testRenderSystemPromptSubstitutesPlaceholders() {
		let rendered = RefineSettings.renderSystemPrompt(
			"Sending into {appName} ({bundleID}).",
			appName: "Slack",
			bundleID: "com.tinyspeck.slackmacgap"
		)
		XCTAssertEqual(rendered, "Sending into Slack (com.tinyspeck.slackmacgap).")
	}

	func testRenderSystemPromptFallsBackWhenAppUnknown() {
		let rendered = RefineSettings.renderSystemPrompt(
			"app={appName} id={bundleID}",
			appName: nil,
			bundleID: nil
		)
		XCTAssertEqual(rendered, "app=an unknown app id=unknown")
	}

	func testRenderSystemPromptTreatsEmptyStringsAsMissing() {
		let rendered = RefineSettings.renderSystemPrompt(
			"app={appName} id={bundleID}",
			appName: "",
			bundleID: ""
		)
		XCTAssertEqual(rendered, "app=an unknown app id=unknown")
	}
}
