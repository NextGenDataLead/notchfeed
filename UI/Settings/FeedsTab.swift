import NotchFeedCore
import SwiftUI

/// FR-4.1 (feed URL) and the feed list. Plain http needs an explicit, per-feed opt-in (see DECISIONS.md).
struct FeedsTab: View {
    let model: AppModel

    @State private var input = ""
    @State private var isAdding = false
    @State private var error: SubscribeError?
    @State private var allowInsecure = false
    @State private var feedToRemove: FeedRow?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            addFeedForm
            Divider()
            if model.feeds.isEmpty {
                ContentUnavailableView("No feeds yet", systemImage: "dot.radiowaves.up.forward",
                                       description: Text("Paste the address of an RSS or Atom feed above."))
            } else {
                List(model.feeds) { feed in
                    FeedRowView(feed: feed) { feedToRemove = feed }
                }
                .listStyle(.inset)
            }
        }
        .padding(20)
        .confirmationDialog(
            "Remove \(feedToRemove?.title ?? "")?",
            isPresented: Binding(get: { feedToRemove != nil }, set: { if !$0 { feedToRemove = nil } }),
            presenting: feedToRemove
        ) { feed in
            Button("Remove Feed", role: .destructive) { model.removeFeed(feed.id) }
        } message: { _ in
            Text("Its headlines are removed too.")
        }
    }

    private var addFeedForm: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                TextField("Feed address", text: $input, prompt: Text(verbatim: "https://example.com/feed.xml"))
                    .textFieldStyle(.roundedBorder)
                    .onSubmit(add)
                    .onChange(of: input) {
                        error = nil
                        allowInsecure = false
                    }
                    .disabled(isAdding)
                if isAdding {
                    ProgressView().controlSize(.small)
                }
                Button("Add", action: add)
                    .keyboardShortcut(.defaultAction)
                    .disabled(isAdding || input.trimmingCharacters(in: .whitespaces).isEmpty
                              || (httpsFailure != nil && !allowInsecure))
            }

            if let httpsFailure {
                InsecureWarning(httpsFailure: httpsFailure, allowInsecure: $allowInsecure)
            } else if let error {
                Label(FeedErrorText.message(for: error), systemImage: "exclamationmark.circle")
                    .foregroundStyle(.red)
                    .font(.callout)
            }
        }
    }

    /// Set when the https attempt failed and plain http needs the user's opt-in.
    private var httpsFailure: FetchError? {
        if case .httpsUnavailable(let reason) = error { reason } else { nil }
    }

    private func add() {
        guard !isAdding else { return }
        isAdding = true
        error = nil
        let allowsInsecure = allowInsecure
        Task {
            defer { isAdding = false }
            do throws(SubscribeError) {
                try await model.subscribe(input, allowsInsecure: allowsInsecure)
                input = ""
                allowInsecure = false
            } catch {
                self.error = error
            }
        }
    }
}

private struct InsecureWarning: View {
    let httpsFailure: FetchError
    @Binding var allowInsecure: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label("This feed doesn't work over a secure (https) connection.", systemImage: "exclamationmark.triangle.fill")
                .font(.callout.weight(.semibold))
                .foregroundStyle(.orange)
            Text("Over https: \(FeedErrorText.message(for: httpsFailure))")
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Text("You can use plain http instead. Without encryption, others on your network can see which feed you read and change the headlines you receive, including the links they open.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Toggle("Allow insecure connection for this feed", isOn: $allowInsecure)
                .toggleStyle(.checkbox)
        }
        .padding(10)
        .background(.orange.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
    }
}

private struct FeedRowView: View {
    let feed: FeedRow
    let onRemove: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            FaviconView(image: feed.favicon, fallbackLetter: feed.title.first)
                .environment(\.colorScheme, .dark)
                .padding(.top, 2)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(feed.title.isEmpty ? feed.url.absoluteString : feed.title)
                        .fontWeight(.medium)
                        .lineLimit(1)
                    if feed.allowsInsecureConnection {
                        Label("Not secure", systemImage: "lock.open.fill")
                            .font(.caption)
                            .foregroundStyle(.orange)
                            .help("This feed uses plain http.")
                    }
                }
                Text(feed.url.absoluteString)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .textSelection(.enabled)
                status
            }
            Spacer()
            Button(role: .destructive, action: onRemove) {
                Image(systemName: "trash")
            }
            .buttonStyle(.borderless)
            .help("Remove feed")
            .accessibilityLabel("Remove \(feed.title)")
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private var status: some View {
        if let error = feed.error {
            Text(FeedErrorText.message(for: error, retryAfter: feed.retryAfter))
                .font(.caption)
                .foregroundStyle(.red)
        } else if let fetched = feed.lastFetchedAt {
            Text("Updated \(fetched, format: .relative(presentation: .named))")
                .font(.caption)
                .foregroundStyle(.secondary)
        } else {
            Text("Not fetched yet")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}
