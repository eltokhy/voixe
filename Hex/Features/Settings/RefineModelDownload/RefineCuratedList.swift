import ComposableArchitecture
import Inject
import SwiftUI

struct RefineCuratedList: View {
  @ObserveInjection var inject
  @Bindable var store: StoreOf<RefineModelDownloadFeature>

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      ForEach(store.models, id: \.huggingFaceRepo) { model in
        RefineCuratedRow(store: store, model: model)
      }
      if let error = store.downloadError {
        Text(error)
          .font(.caption)
          .foregroundStyle(.red)
      }
    }
    .task {
      store.send(.task)
    }
    .enableInjection()
  }
}
