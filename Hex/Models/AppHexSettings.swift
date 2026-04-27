import ComposableArchitecture
import Dependencies
import Foundation
import VoixeCore

// Re-export types so the app target can use them without VoixeCore prefixes.
typealias RecordingAudioBehavior = VoixeCore.RecordingAudioBehavior
typealias VoixeSettings = VoixeCore.VoixeSettings

extension SharedReaderKey
	where Self == FileStorageKey<VoixeSettings>.Default
{
	static var hexSettings: Self {
		Self[
			.fileStorage(.hexSettingsURL),
			default: .init()
		]
	}
}

// MARK: - Storage Migration

extension URL {
	static var hexSettingsURL: URL {
		get {
			URL.hexMigratedFileURL(named: "hex_settings.json")
		}
	}
}
