import Combine
import ComposableArchitecture
import Inject
import Sparkle
import SwiftUI

@Observable
@MainActor
final class CheckForUpdatesViewModel {
	init() {
		anyCancellable = controller.updater.publisher(for: \.canCheckForUpdates)
			.sink(receiveValue: { self.canCheckForUpdates = $0 })
	}

	static let shared = CheckForUpdatesViewModel()

	// startingUpdater is false until Voixe has a real Sparkle feed URL +
	// signed/notarized release. While SUFeedURL is the placeholder, booting the
	// Sparkle updater would immediately try to launch its XPC helper and fail
	// with "The updater failed to start" on every launch. The Check-for-Updates
	// button stays disabled (canCheckForUpdates = false) until startUpdater is
	// called, so the user never sees a misleading error.
	let controller = SPUStandardUpdaterController(
		startingUpdater: false,
		updaterDelegate: nil,
		userDriverDelegate: nil
	)

	var anyCancellable: AnyCancellable?

	var canCheckForUpdates = false

	func checkForUpdates() {
		controller.updater.checkForUpdates()
	}
}

struct CheckForUpdatesView: View {
	@State var viewModel = CheckForUpdatesViewModel.shared
	@ObserveInjection var inject

	var body: some View {
		Button("Check for Updates…", action: viewModel.checkForUpdates)
			.disabled(!viewModel.canCheckForUpdates)
			.enableInjection()
	}
}
