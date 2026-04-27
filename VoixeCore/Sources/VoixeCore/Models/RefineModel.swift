import Foundation

/// A curated downloadable refine model. The on-disk identifier is the
/// HuggingFace repository (e.g. `mlx-community/Qwen2.5-1.5B-Instruct-4bit`),
/// which is also used as the directory slug under
/// `~/Library/Application Support/com.enginecy.voixe/refine-models/`.
public struct RefineModel: Codable, Equatable, Identifiable, Sendable {
	public var id: String { huggingFaceRepo }
	public var displayName: String
	public var huggingFaceRepo: String
	public var accuracyStars: Int
	public var speedStars: Int
	public var storageSize: String
	public var sizeBytes: Int64
	public var badge: String?
	public var summary: String?

	public init(
		displayName: String,
		huggingFaceRepo: String,
		accuracyStars: Int,
		speedStars: Int,
		storageSize: String,
		sizeBytes: Int64,
		badge: String? = nil,
		summary: String? = nil
	) {
		self.displayName = displayName
		self.huggingFaceRepo = huggingFaceRepo
		self.accuracyStars = accuracyStars
		self.speedStars = speedStars
		self.storageSize = storageSize
		self.sizeBytes = sizeBytes
		self.badge = badge
		self.summary = summary
	}

	/// File-system safe slug derived from the HF repo id.
	public var directorySlug: String {
		huggingFaceRepo.replacingOccurrences(of: "/", with: "_")
	}
}

/// Hard-coded fallback list used when `refine-models.json` is missing from the bundle.
/// Kept in sync with `Hex/Resources/Data/refine-models.json` — JSON wins at runtime.
public enum RefineModelCatalog {
	public static let `default`: [RefineModel] = [
		RefineModel(
			displayName: "Refine Tiny",
			huggingFaceRepo: "mlx-community/Qwen2.5-0.5B-Instruct-4bit",
			accuracyStars: 2,
			speedStars: 5,
			storageSize: "300 MB",
			sizeBytes: 314_572_800,
			badge: nil,
			summary: "Fastest. Cleans up fillers and punctuation. Limited at translation or complex commands."
		),
		RefineModel(
			displayName: "Refine Small",
			huggingFaceRepo: "mlx-community/Llama-3.2-1B-Instruct-4bit",
			accuracyStars: 3,
			speedStars: 4,
			storageSize: "700 MB",
			sizeBytes: 734_003_200,
			badge: "BEST FOR ENGLISH",
			summary: "Strong English cleanup and command following. Multilingual but limited."
		),
		RefineModel(
			displayName: "Refine Default",
			huggingFaceRepo: "mlx-community/Qwen2.5-1.5B-Instruct-4bit",
			accuracyStars: 4,
			speedStars: 4,
			storageSize: "900 MB",
			sizeBytes: 943_718_400,
			badge: "BEST FOR MULTILINGUAL",
			summary: "Balanced default. Handles cleanup, commands, and translation well."
		),
		RefineModel(
			displayName: "Refine Large",
			huggingFaceRepo: "mlx-community/Qwen2.5-3B-Instruct-4bit",
			accuracyStars: 5,
			speedStars: 3,
			storageSize: "1.8 GB",
			sizeBytes: 1_887_436_800,
			badge: "HIGHEST QUALITY",
			summary: "Best refinement quality at small size. Slowest of the four; best for batched cleanup."
		)
	]

	public static var defaultModelID: String {
		`default`[2].huggingFaceRepo
	}
}
