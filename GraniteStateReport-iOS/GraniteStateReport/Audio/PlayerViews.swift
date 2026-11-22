import SwiftUI

/// The strip above the tab bar while something is playing.
struct MiniPlayerBar: View {
    @Environment(AudioPlayer.self) private var player
    @State private var showsFullPlayer = false

    var body: some View {
        if let track = player.current {
            HStack(spacing: 14) {
                Button {
                    showsFullPlayer = true
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: track.isLive ? "dot.radiowaves.left.and.right" : "waveform")
                            .font(.body.weight(.semibold))
                            .foregroundStyle(Color.gsrBrick)
                            .frame(width: 28)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(track.title)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(Color.gsrInk)
                                .lineLimit(1)
                            Text(statusLine(for: track))
                                .font(.caption)
                                .foregroundStyle(Color.gsrMuted)
                                .lineLimit(1)
                                .monospacedDigit()
                        }
                        Spacer(minLength: 0)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Now playing: \(track.title)")
                .accessibilityHint("Opens the player")

                Button {
                    player.toggle()
                } label: {
                    Image(systemName: player.isPlaying || player.isBuffering ? "pause.fill" : "play.fill")
                        .font(.title3)
                        .frame(width: 36, height: 36)
                }
                .accessibilityLabel(player.isPlaying ? "Pause" : "Play")

                Button {
                    player.stop()
                } label: {
                    Image(systemName: "xmark")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.gsrMuted)
                        .frame(width: 32, height: 36)
                }
                .accessibilityLabel("Close player")
            }
            .padding(.leading, 14)
            .padding(.trailing, 8)
            .padding(.vertical, 7)
            .background(.regularMaterial)
            .overlay(alignment: .top) { Hairline() }
            .overlay(alignment: .bottom) {
                if player.canSeek {
                    GeometryReader { geometry in
                        Rectangle()
                            .fill(Color.gsrBrick)
                            .frame(width: geometry.size.width * fraction, height: 2)
                    }
                    .frame(height: 2)
                }
            }
            .sheet(isPresented: $showsFullPlayer) {
                NowPlayingView()
                    .environment(player)
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
            }
        }
    }

    private var fraction: Double {
        guard player.duration > 0 else { return 0 }
        return min(max(player.currentTime / player.duration, 0), 1)
    }

    private func statusLine(for track: AudioTrack) -> String {
        if player.didFail { return "Could not play this audio" }
        if track.isLive { return "Live" }
        if player.isBuffering { return "Loading" }
        if player.duration > 0 {
            return "\(player.currentTime.clockString) of \(player.duration.clockString)"
        }
        return track.subtitle
    }
}

extension View {
    /// Docks the mini player above the tab bar for this tab.
    func miniPlayer() -> some View {
        safeAreaInset(edge: .bottom, spacing: 0) {
            MiniPlayerBar()
        }
    }
}

/// The full player sheet.
struct NowPlayingView: View {
    @Environment(AudioPlayer.self) private var player
    @Environment(\.openURL) private var openURL
    @State private var scrubPosition: Double?

    var body: some View {
        VStack(spacing: 22) {
            if let track = player.current {
                VStack(spacing: 8) {
                    Kicker(text: track.isLive ? "Live" : track.subtitle)
                    Text(track.title)
                        .font(.gsrSerif(22, relativeTo: .title2))
                        .foregroundStyle(Color.gsrInk)
                        .multilineTextAlignment(.center)
                        .lineLimit(4)
                        .minimumScaleFactor(0.8)
                }
                .padding(.top, 28)

                if player.didFail {
                    Label("This audio could not be played.", systemImage: "exclamationmark.triangle")
                        .font(.subheadline)
                        .foregroundStyle(Color.gsrMuted)
                }

                if player.canSeek {
                    scrubber
                }

                controls(isLive: track.isLive)

                HStack {
                    if !track.isLive {
                        speedMenu
                    }
                    Spacer()
                    if let link = track.link {
                        Button {
                            openURL(link)
                        } label: {
                            Label("Open page", systemImage: "arrow.up.right")
                                .font(.subheadline.weight(.medium))
                        }
                    }
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.gsrPaper.ignoresSafeArea())
    }

    private var scrubber: some View {
        VStack(spacing: 4) {
            Slider(
                value: Binding(
                    get: { scrubPosition ?? player.currentTime },
                    set: { scrubPosition = $0 }
                ),
                in: 0...max(player.duration, 1),
                onEditingChanged: { editing in
                    if !editing, let position = scrubPosition {
                        player.seek(to: position)
                        scrubPosition = nil
                    }
                }
            )
            .accessibilityLabel("Playback position")
            .accessibilityValue((scrubPosition ?? player.currentTime).clockString)

            HStack {
                Text((scrubPosition ?? player.currentTime).clockString)
                Spacer()
                Text("-" + max(player.duration - (scrubPosition ?? player.currentTime), 0).clockString)
            }
            .font(.caption)
            .monospacedDigit()
            .foregroundStyle(Color.gsrMuted)
        }
    }

    private func controls(isLive: Bool) -> some View {
        HStack(spacing: 30) {
            if !isLive {
                Button {
                    player.skip(by: -15)
                } label: {
                    Image(systemName: "gobackward.15").font(.title)
                }
                .disabled(!player.canSeek)
                .accessibilityLabel("Back 15 seconds")
            }

            Button {
                player.toggle()
            } label: {
                Image(systemName: player.isPlaying || player.isBuffering ? "pause.circle.fill" : "play.circle.fill")
                    .font(.system(size: 68))
            }
            .accessibilityLabel(player.isPlaying ? "Pause" : "Play")

            if !isLive {
                Button {
                    player.skip(by: 30)
                } label: {
                    Image(systemName: "goforward.30").font(.title)
                }
                .disabled(!player.canSeek)
                .accessibilityLabel("Forward 30 seconds")
            }
        }
    }

    private var speedMenu: some View {
        Menu {
            ForEach(AudioPlayer.speeds, id: \.self) { speed in
                Button {
                    player.setSpeed(speed)
                } label: {
                    if speed == player.speed {
                        Label(speedLabel(speed), systemImage: "checkmark")
                    } else {
                        Text(speedLabel(speed))
                    }
                }
            }
        } label: {
            Label(speedLabel(player.speed), systemImage: "speedometer")
                .font(.subheadline.weight(.medium))
        }
        .accessibilityLabel("Playback speed")
    }

    private func speedLabel(_ speed: Float) -> String {
        let text = speed == speed.rounded() ? String(format: "%.0f", speed) : String(speed)
        return text + "×"
    }
}
