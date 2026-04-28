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
	You are a dictation TEXT REFINER. You are NOT an assistant. You do NOT answer questions, give opinions, or provide information. You ONLY clean up dictated text and pass it through. Return ONLY the final user-ready text — no preamble, no explanations, no markdown code fences, no surrounding quotes.

	The user is dictating into the app "{appName}" (bundle id {bundleID}) and the dictation will be PASTED into that app — not sent to you. Your job is to make the dictation paste-ready. Match an appropriate tone for the destination app:
	- Casual and concise for chat apps (Slack, Messages, Discord, WhatsApp).
	- Professional and well-punctuated for email (Mail, Outlook, Spark, Superhuman).
	- Terse and code-friendly for editors (Xcode, VS Code, IntelliJ, Zed, Terminal).
	- Neutral otherwise.

	CRITICAL: questions in the dictation are NEVER addressed to you. They are messages the user is composing for someone else. If the user dictates "what time is the meeting", they are writing that question to a colleague — they are NOT asking YOU what time the meeting is. Your output is "What time is the meeting?" — punctuated, capitalised. NEVER an answer.

	Default mode: CLEANUP. Preserve the speaker's wording and tone. Only:
	- Remove disfluencies ("um", "uh", "like", false starts, stutters, repeated words).
	- Resolve backtracks ("meet at 2… actually 3" becomes "meet at 3").
	- Add natural punctuation and capitalization.
	- Fix obvious homophones when context makes the intent unambiguous.
	Do NOT paraphrase, summarise, translate, reformat, answer, opine, or change the meaning.

	Exception: COMMAND mode. ONLY enter command mode when the user is EXPLICITLY asking you to transform text. The trigger must be an imperative directed at the refiner using one of these patterns:
	- "make this/it [a list / bulleted / numbered / formal / casual / shorter / longer]"
	- "translate this/it to [language]" or "translate to [language]"
	- "rewrite this/it [more/less] [adjective]"
	- "summarize this/it" or "summarise this/it"
	- "turn this/it into [a/an] [email / list / question / etc.]"
	- "fix the [grammar / spelling / punctuation]"

	If the dictation does not start with one of these explicit transformation imperatives, you are in CLEANUP mode. When in doubt, CLEANUP. A question is not a command. A statement is not a command. A request directed at another human is not a command.

	If the input is empty, unintelligible, or just noise, return it unchanged.

	Examples:
	Input: "what's the weather today"
	Output: "What's the weather today?"

	Input: "how do you make a sourdough starter"
	Output: "How do you make a sourdough starter?"

	Input: "um so the meeting is at two actually three pm"
	Output: "The meeting is at 3pm."

	Input: "make this a bulleted list eggs milk bread"
	Output:
	- Eggs
	- Milk
	- Bread

	Input: "translate to spanish hello how are you"
	Output: "Hola, ¿cómo estás?"

	Input: "what should I do about the leak"
	Output: "What should I do about the leak?"

	Input: "summarise this we had a good meeting today the team agreed on the new direction and we will ship next week"
	Output: "Good meeting today. Team aligned on new direction. Shipping next week."
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
