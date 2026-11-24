import SwiftUI

struct TodayView: View {
    @Environment(Router.self) private var router
    @Environment(\.openURL) private var openURL

    @State private var feed = FeedModel(query: .latest, cacheName: "front-page")
    @State private var path: [Route] = []
    @State private var live: LiveStatus?
    @State private var showsAbout = false

    var body: some View {
        NavigationStack(path: $path) {
            ScrollView {
                VStack(spacing: 0) {
                    dateline
                    if let live, live.live {
                        liveBanner(live)
                    }
                    FeedContent(feed: feed, showsLead: true)
                }
            }
            .background(Color.gsrPaper)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Image("Masthead")
                        .resizable()
                        .scaledToFit()
                        .frame(height: 26)
                        .accessibilityLabel(GSR.name)
                        .accessibilityAddTraits(.isHeader)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showsAbout = true
                    } label: {
                        Image(systemName: "info.circle")
                    }
                    .accessibilityLabel("About and settings")
                }
            }
            .refreshable {
                await feed.refresh()
                await loadLiveStatus()
            }
            .gsrDestinations()
        }
        .task {
            await feed.loadIfNeeded()
            await loadLiveStatus()
        }
        .onChange(of: router.pendingPostID, initial: true) { _, postID in
            guard let postID else { return }
            showsAbout = false
            path = [.post(id: postID)]
            router.pendingPostID = nil
        }
        .sheet(isPresented: $showsAbout) {
            AboutView()
        }
    }

    private var dateline: some View {
        VStack(spacing: 4) {
            Text(Date().formatted(date: .complete, time: .omitted).uppercased())
                .font(.caption2.weight(.semibold))
                .tracking(1.2)
                .foregroundStyle(Color.gsrMuted)
            Text(GSR.tagline)
                .font(.gsrSerif(13, bold: false, relativeTo: .footnote))
                .italic()
                .foregroundStyle(Color.gsrMuted)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .overlay(alignment: .bottom) { Hairline() }
    }

    private func liveBanner(_ status: LiveStatus) -> some View {
        Button {
            if let url = status.watchURL {
                openURL(url)
            }
        } label: {
            HStack(spacing: 10) {
                Circle()
                    .fill(Color.white)
                    .frame(width: 8, height: 8)
                VStack(alignment: .leading, spacing: 2) {
                    Text((status.label ?? "GSR is live").uppercased())
                        .font(.caption.weight(.bold))
                        .tracking(1.2)
                    if let title = status.title, !title.isEmpty {
                        Text(title)
                            .font(.subheadline)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                    }
                }
                Spacer(minLength: 0)
                Image(systemName: "play.fill")
            }
            .foregroundStyle(Color.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color(red: 0.69, green: 0.29, blue: 0.22))
        }
        .buttonStyle(.plain)
        .accessibilityHint("Opens the live stream")
    }

    private func loadLiveStatus() async {
        live = try? await WordPressAPI.shared.liveStatus()
    }
}
