import SwiftUI

/// Podcast episodes, narrated articles and video, from the site's own media catalog.
struct ListenView: View {
    @Environment(AudioPlayer.self) private var player
    @Environment(\.openURL) private var openURL

    @State private var tabs: [MediaTab] = []
    @State private var selectedID: String?
    @State private var errorMessage: String?
    @State private var isLoading = false

    private var selected: MediaTab? {
        tabs.first { $0.id == selectedID } ?? tabs.first
    }

    var body: some View {
        NavigationStack {
            Group {
                if tabs.isEmpty {
                    if let errorMessage {
                        ContentUnavailableView {
                            Label("Couldn't load audio and video", systemImage: "wifi.slash")
                        } description: {
                            Text(errorMessage)
                        } actions: {
                            Button("Try Again") {
                                Task { await load() }
                            }
                            .buttonStyle(.borderedProminent)
                        }
                    } else {
                        ProgressView()
                    }
                } else {
                    content
                }
            }
            .background(Color.gsrPaper)
            .navigationTitle("Listen & Watch")
        }
        .task {
            if tabs.isEmpty { await load() }
        }
    }

    private var content: some View {
        VStack(spacing: 0) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(tabs) { tab in
                        let isSelected = tab.id == selected?.id
                        Button {
                            selectedID = tab.id
                        } label: {
                            Text(tab.displayName)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(isSelected ? Color.white : Color.gsrInk)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 8)
                                .background(isSelected ? Color.gsrBrick : Color.gsrSurface, in: Capsule())
                                .overlay(Capsule().stroke(isSelected ? Color.clear : Color.gsrRule))
                        }
                        .buttonStyle(.plain)
                        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
            }
            Hairline()

            if let tab = selected {
                List {
                    if let note = tab.note, !note.isEmpty {
                        Text(HTMLText.decodeEntities(note))
                            .font(.footnote)
                            .foregroundStyle(Color.gsrMuted)
                            .listRowBackground(Color.gsrPaper)
                            .listRowSeparator(.hidden)
                    }
                    ForEach(Array(tab.items.enumerated()), id: \.offset) { _, item in
                        row(item, in: tab)
                            .listRowBackground(Color.gsrPaper)
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .refreshable { await load() }
                .id(tab.id)
            }
        }
    }

    @ViewBuilder
    private func row(_ item: MediaItem, in tab: MediaTab) -> some View {
        if item.isAudio {
            audioRow(item, in: tab)
        } else if let link = item.linkURL {
            Button {
                openURL(link)
            } label: {
                videoRow(item)
            }
            .buttonStyle(.plain)
            .accessibilityHint("Opens the video")
        }
    }

    private func audioRow(_ item: MediaItem, in tab: MediaTab) -> some View {
        let isCurrent = player.current?.url == item.audioURL
        return Button {
            play(item, in: tab)
        } label: {
            HStack(spacing: 14) {
                Image(systemName: isCurrent && player.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                    .font(.system(size: 34))
                    .foregroundStyle(Color.gsrBrick)
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.displayTitle)
                        .font(.gsrSerif(17, relativeTo: .headline))
                        .foregroundStyle(Color.gsrInk)
                        .lineLimit(3)
                        .multilineTextAlignment(.leading)
                    if item.isLive {
                        Kicker(text: "Live")
                    } else if let sub = item.sub, !sub.isEmpty {
                        Text(sub)
                            .font(.caption)
                            .foregroundStyle(Color.gsrMuted)
                    }
                }
                Spacer(minLength: 0)
            }
            .padding(.vertical, 6)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel((isCurrent && player.isPlaying ? "Pause " : "Play ") + item.displayTitle)
    }

    private func videoRow(_ item: MediaItem) -> some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                if item.thumbnailURL != nil {
                    RemoteImage(url: item.thumbnailURL)
                } else {
                    Color.gsrInk
                    Image(systemName: "list.and.film")
                        .font(.title2)
                        .foregroundStyle(Color.white)
                }
            }
            .frame(width: 128, height: 72)
            .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
            .overlay(alignment: .bottomTrailing) {
                if item.thumbnailURL != nil {
                    Image(systemName: "play.fill")
                        .font(.caption2)
                        .foregroundStyle(Color.white)
                        .padding(5)
                        .background(Color.black.opacity(0.65), in: RoundedRectangle(cornerRadius: 3))
                        .padding(4)
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(item.displayTitle)
                    .font(.gsrSerif(16, relativeTo: .subheadline))
                    .foregroundStyle(Color.gsrInk)
                    .lineLimit(3)
                    .multilineTextAlignment(.leading)
                if let sub = item.sub, !sub.isEmpty {
                    Text(sub)
                        .font(.caption)
                        .foregroundStyle(Color.gsrMuted)
                }
            }
            Spacer(minLength: 0)
            Image(systemName: "arrow.up.right")
                .font(.caption)
                .foregroundStyle(Color.gsrMuted)
        }
        .padding(.vertical, 6)
        .contentShape(Rectangle())
    }

    private func track(for item: MediaItem, in tab: MediaTab) -> AudioTrack? {
        guard let url = item.audioURL else { return nil }
        return AudioTrack(url: url,
                          title: item.displayTitle,
                          subtitle: tab.displayName,
                          isLive: item.isLive,
                          link: item.linkURL)
    }

    private func play(_ item: MediaItem, in tab: MediaTab) {
        guard let chosen = track(for: item, in: tab) else { return }
        if player.current == chosen {
            player.toggle()
            return
        }
        // Live streams play alone. Episodes queue up so the next one follows.
        let queue = item.isLive
            ? [chosen]
            : tab.items.filter { $0.isAudio && !$0.isLive }.compactMap { track(for: $0, in: tab) }
        player.play(chosen, queue: queue)
    }

    private func load() async {
        guard !isLoading else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            let catalog = try await WordPressAPI.shared.mediaCatalog()
            tabs = catalog.tabs.filter { !GSR.hiddenMediaTabs.contains($0.id) && !$0.items.isEmpty }
            errorMessage = nil
        } catch is CancellationError {
            return
        } catch {
            if tabs.isEmpty {
                errorMessage = error.localizedDescription
            }
        }
    }
}
