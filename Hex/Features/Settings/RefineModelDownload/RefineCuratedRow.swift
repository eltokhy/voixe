import ComposableArchitecture
import VoixeCore
import Inject
import SwiftUI

struct RefineCuratedRow: View {
  @ObserveInjection var inject
  @Bindable var store: StoreOf<RefineModelDownloadFeature>
  let model: RefineModel

  var isSelected: Bool {
    store.selectedRepo == model.huggingFaceRepo
  }

  var isDownloaded: Bool {
    store.downloadedRepos.contains(model.huggingFaceRepo)
  }

  var isDownloadingThis: Bool {
    store.isDownloading && store.downloadingRepo == model.huggingFaceRepo
  }

  var body: some View {
    Button(action: { store.send(.selectModel(model.huggingFaceRepo)) }) {
      HStack(alignment: .center, spacing: 12) {
        Image(systemName: isSelected ? "largecircle.fill.circle" : "circle")
          .foregroundStyle(isSelected ? .blue : .secondary)

        VStack(alignment: .leading, spacing: 6) {
          HStack(spacing: 6) {
            Text(model.displayName)
              .font(.headline)
            if let badge = model.badge {
              Text(badge)
                .font(.caption2)
                .fontWeight(.semibold)
                .foregroundStyle(.white)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color.accentColor)
                .clipShape(RoundedRectangle(cornerRadius: 4))
            }
          }
          HStack(spacing: 16) {
            HStack(spacing: 6) {
              StarRatingView(model.accuracyStars)
              Text("Accuracy").font(.caption2).foregroundStyle(.secondary)
            }
            HStack(spacing: 6) {
              StarRatingView(model.speedStars)
              Text("Speed").font(.caption2).foregroundStyle(.secondary)
            }
          }
          if let summary = model.summary {
            Text(summary)
              .font(.caption2)
              .foregroundStyle(.secondary)
              .lineLimit(2)
              .fixedSize(horizontal: false, vertical: true)
          }
        }

        Spacer(minLength: 12)

        HStack(spacing: 12) {
          Text(model.storageSize)
            .foregroundStyle(.secondary)
            .font(.subheadline)
            .frame(width: 72, alignment: .trailing)

          ZStack {
            if isDownloadingThis {
              ProgressView(value: store.downloadProgress)
                .progressViewStyle(.circular)
                .controlSize(.small)
                .tint(.blue)
                .frame(width: 24, height: 24)
                .help("Downloading… \(Int(store.downloadProgress * 100))%")
            } else if isDownloaded {
              Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
                .frame(width: 24, height: 24)
                .help("Downloaded")
            } else {
              Button {
                store.send(.selectModel(model.huggingFaceRepo))
                store.send(.downloadModel(model.huggingFaceRepo))
              } label: {
                Image(systemName: "arrow.down.circle")
              }
              .buttonStyle(.borderless)
              .help("Download")
              .frame(width: 24, height: 24)
            }
          }
        }
      }
      .padding(10)
      .background(
        RoundedRectangle(cornerRadius: 10)
          .fill(isSelected ? Color.blue.opacity(0.08) : Color(NSColor.controlBackgroundColor))
      )
      .overlay(
        RoundedRectangle(cornerRadius: 10)
          .stroke(isSelected ? Color.blue.opacity(0.35) : Color.gray.opacity(0.18))
      )
      .contentShape(.rect)
    }
    .buttonStyle(.plain)
    .contextMenu {
      if isDownloadingThis {
        Button("Cancel Download", role: .destructive) { store.send(.cancelDownload) }
      }
      if isDownloaded || isDownloadingThis {
        Button("Show in Finder") { store.send(.revealInFinder(model.huggingFaceRepo)) }
      }
      if isDownloaded {
        Divider()
        Button("Delete", role: .destructive) {
          store.send(.deleteModel(model.huggingFaceRepo))
        }
      }
    }
    .enableInjection()
  }
}
