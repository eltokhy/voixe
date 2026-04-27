import Foundation

/// Where the refine pass should run.
public enum RefineRuntimeMode: String, Codable, Sendable, Equatable, CaseIterable {
	/// Run inference in-process via MLX-Swift on a downloaded model.
	case bundled
	/// Send to a local HTTP endpoint (Ollama-compatible).
	case ollama
}

/// User-configurable settings for the optional local-LLM refine pass.
///
/// Two backends are supported (see `runtimeMode`):
/// - `bundled`: in-process MLX inference on a model downloaded into
///   `~/Library/Application Support/com.enginecy.voixe/refine-models/`.
/// - `ollama`: HTTP request to a user-configured local endpoint.
///
/// Codable is hand-rolled so missing keys fall back to defaults — important for
/// migrating older settings blobs that predate `runtimeMode` / `bundledModelID`.
public struct RefineSettings: Equatable, Sendable {
	public var isEnabled: Bool
	public var runtimeMode: RefineRuntimeMode
	public var bundledModelID: String
	public var endpoint: String
	public var model: String
	public var systemPrompt: String
	public var temperature: Double
	public var timeoutSeconds: Double
	public var fallbackOnError: Bool

	public init(
		isEnabled: Bool = false,
		runtimeMode: RefineRuntimeMode = .bundled,
		bundledModelID: String = RefineModelCatalog.defaultModelID,
		endpoint: String = RefineSettings.defaultEndpoint,
		model: String = RefineSettings.defaultModel,
		systemPrompt: String = RefineSettings.defaultSystemPrompt,
		temperature: Double = 0.2,
		timeoutSeconds: Double = 8,
		fallbackOnError: Bool = true
	) {
		self.isEnabled = isEnabled
		self.runtimeMode = runtimeMode
		self.bundledModelID = bundledModelID
		self.endpoint = endpoint
		self.model = model
		self.systemPrompt = systemPrompt
		self.temperature = temperature
		self.timeoutSeconds = timeoutSeconds
		self.fallbackOnError = fallbackOnError
	}

	public static let defaultEndpoint = "http://localhost:11434"
	public static let defaultModel = "gemma4:e4b"

	public static let defaultSystemPrompt = """
	You are a dictation refiner. Return ONLY the final user-ready text — no preamble, no explanations, no markdown code fences, no surrounding quotes.

	The user is dictating into the app "{appName}" (bundle id {bundleID}). Match an appropriate tone for that app:
	- Casual and concise for chat apps (Slack, Messages, Discord, WhatsApp).
	- Professional and well-punctuated for email (Mail, Outlook, Spark, Superhuman).
	- Terse and code-friendly for editors (Xcode, VS Code, IntelliJ, Zed, Terminal).
	- Neutral otherwise.

	Decide between two modes based on the input:

	1. COMMAND mode — if the user is issuing a command such as "make this a bulleted list", "translate to Spanish", "rewrite more formally", "summarize this", "turn this into an email", then execute the command on any content in the same utterance. If there is no content beyond the command itself, treat the command words as the content.

	2. CLEANUP mode — otherwise, preserve the speaker's wording and tone. Only:
	   - Remove disfluencies ("um", "uh", "like", false starts, stutters, repeated words).
	   - Resolve backtracks ("meet at 2… actually 3" becomes "meet at 3").
	   - Add natural punctuation and capitalization.
	   - Fix obvious homophones only when context makes the intent unambiguous.
	   Do NOT paraphrase, summarize, translate, reformat, or change the meaning.

	If the input is empty, unintelligible, or just noise, return it unchanged.
	"""

	/// Substitute `{appName}` / `{bundleID}` placeholders in a prompt template.
	public static func renderSystemPrompt(
		_ template: String,
		appName: String?,
		bundleID: String?
	) -> String {
		let name = (appName?.isEmpty == false ? appName : nil) ?? "an unknown app"
		let bundle = (bundleID?.isEmpty == false ? bundleID : nil) ?? "unknown"
		return template
			.replacingOccurrences(of: "{appName}", with: name)
			.replacingOccurrences(of: "{bundleID}", with: bundle)
	}
}

// MARK: - Codable

extension RefineSettings: Codable {
	private enum CodingKeys: String, CodingKey {
		case isEnabled, runtimeMode, bundledModelID, endpoint, model, systemPrompt, temperature, timeoutSeconds, fallbackOnError
	}

	public init(from decoder: Decoder) throws {
		self.init()
		let container = try decoder.container(keyedBy: CodingKeys.self)
		if let v = try container.decodeIfPresent(Bool.self, forKey: .isEnabled) { isEnabled = v }
		if let v = try container.decodeIfPresent(RefineRuntimeMode.self, forKey: .runtimeMode) { runtimeMode = v }
		if let v = try container.decodeIfPresent(String.self, forKey: .bundledModelID) { bundledModelID = v }
		if let v = try container.decodeIfPresent(String.self, forKey: .endpoint) { endpoint = v }
		if let v = try container.decodeIfPresent(String.self, forKey: .model) { model = v }
		if let v = try container.decodeIfPresent(String.self, forKey: .systemPrompt) { systemPrompt = v }
		if let v = try container.decodeIfPresent(Double.self, forKey: .temperature) { temperature = v }
		if let v = try container.decodeIfPresent(Double.self, forKey: .timeoutSeconds) { timeoutSeconds = v }
		if let v = try container.decodeIfPresent(Bool.self, forKey: .fallbackOnError) { fallbackOnError = v }
	}

	public func encode(to encoder: Encoder) throws {
		var container = encoder.container(keyedBy: CodingKeys.self)
		try container.encode(isEnabled, forKey: .isEnabled)
		try container.encode(runtimeMode, forKey: .runtimeMode)
		try container.encode(bundledModelID, forKey: .bundledModelID)
		try container.encode(endpoint, forKey: .endpoint)
		try container.encode(model, forKey: .model)
		try container.encode(systemPrompt, forKey: .systemPrompt)
		try container.encode(temperature, forKey: .temperature)
		try container.encode(timeoutSeconds, forKey: .timeoutSeconds)
		try container.encode(fallbackOnError, forKey: .fallbackOnError)
	}
}
