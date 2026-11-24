import AVFoundation
import MediaPlayer
import Observation
import UIKit

/// Something the player can play: an article narration, a podcast episode, or a live stream.
struct AudioTrack: Identifiable, Hashable {
    let url: URL
    let title: String
    let subtitle: String
    var isLive: Bool = false
    /// The story or page this audio belongs to, when there is one.
    var link: URL?

    var id: URL { url }
}

/// One app-wide audio player. Keeps playing in the background and answers the lock screen,
/// Control Center, headphones and CarPlay's now-playing controls.
@MainActor
@Observable
final class AudioPlayer {
    static let shared = AudioPlayer()
    static let speeds: [Float] = [0.8, 1.0, 1.25, 1.5, 2.0]

    private(set) var current: AudioTrack?
    private(set) var queue: [AudioTrack] = []
    private(set) var isPlaying = false
    private(set) var isBuffering = false
    private(set) var didFail = false
    private(set) var currentTime: Double = 0
    private(set) var duration: Double = 0
    private(set) var speed: Float = 1.0

    @ObservationIgnored private let player = AVPlayer()
    @ObservationIgnored private var timeObserver: Any?
    @ObservationIgnored private var statusObservation: NSKeyValueObservation?
    @ObservationIgnored private var itemObservation: NSKeyValueObservation?
    @ObservationIgnored private var observers: [NSObjectProtocol] = []
    @ObservationIgnored private var wantsPlayback = false
    @ObservationIgnored private var loadToken = 0

    private static let speedKey = "playbackSpeed"

    private init() {
        let stored = UserDefaults.standard.float(forKey: AudioPlayer.speedKey)
        if AudioPlayer.speeds.contains(stored) {
            speed = stored
        }
        player.automaticallyWaitsToMinimizeStalling = true
        observePlayer()
        configureRemoteCommands()
    }

    // MARK: Controls

    var hasNext: Bool { index(offset: 1) != nil }
    var hasPrevious: Bool { index(offset: -1) != nil }
    var canSeek: Bool { !(current?.isLive ?? true) && duration > 0 }

    func play(_ track: AudioTrack, queue newQueue: [AudioTrack]? = nil) {
        if let newQueue {
            queue = newQueue
        } else if !queue.contains(track) {
            queue = [track]
        }
        if current == track, player.currentItem != nil, !didFail {
            resume()
            return
        }
        start(track)
    }

    func toggle() {
        if isPlaying || isBuffering {
            pause()
        } else {
            resume()
        }
    }

    func resume() {
        guard let current else { return }
        if didFail || player.currentItem == nil {
            start(current)
            return
        }
        activateSession()
        wantsPlayback = true
        if current.isLive {
            player.play()
        } else {
            player.playImmediately(atRate: speed)
        }
        updateNowPlaying()
    }

    func pause() {
        wantsPlayback = false
        player.pause()
        updateNowPlaying()
    }

    func stop() {
        wantsPlayback = false
        player.pause()
        player.replaceCurrentItem(with: nil)
        itemObservation = nil
        current = nil
        queue = []
        isPlaying = false
        isBuffering = false
        didFail = false
        currentTime = 0
        duration = 0
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    func skip(by seconds: Double) {
        guard canSeek else { return }
        seek(to: currentTime + seconds)
    }

    func seek(to seconds: Double) {
        guard canSeek else { return }
        let target = min(max(seconds, 0), max(duration - 1, 0))
        currentTime = target
        player.seek(to: CMTime(seconds: target, preferredTimescale: 600)) { [weak self] _ in
            Task { @MainActor in self?.updateNowPlaying() }
        }
    }

    func next() {
        guard let index = index(offset: 1) else { return }
        start(queue[index])
    }

    func previous() {
        if canSeek, currentTime > 5 {
            seek(to: 0)
            return
        }
        guard let index = index(offset: -1) else {
            seek(to: 0)
            return
        }
        start(queue[index])
    }

    func setSpeed(_ newSpeed: Float) {
        speed = newSpeed
        UserDefaults.standard.set(newSpeed, forKey: AudioPlayer.speedKey)
        if player.timeControlStatus != .paused, !(current?.isLive ?? true) {
            player.rate = newSpeed
        }
        updateNowPlaying()
    }

    // MARK: Internals

    private func index(offset: Int) -> Int? {
        guard let current, let index = queue.firstIndex(of: current) else { return nil }
        let target = index + offset
        return queue.indices.contains(target) ? target : nil
    }

    private func start(_ track: AudioTrack) {
        loadToken += 1
        let token = loadToken

        current = track
        didFail = false
        currentTime = 0
        duration = 0
        isBuffering = true
        wantsPlayback = true
        activateSession()

        let item = AVPlayerItem(url: track.url)
        item.audioTimePitchAlgorithm = .timeDomain
        itemObservation = item.observe(\.status, options: [.new]) { [weak self] _, _ in
            Task { @MainActor in
                guard let self, token == self.loadToken,
                      self.player.currentItem?.status == .failed
                else { return }
                self.didFail = true
                self.isBuffering = false
                self.isPlaying = false
                self.wantsPlayback = false
            }
        }
        player.replaceCurrentItem(with: item)
        if track.isLive {
            player.play()
        } else {
            player.playImmediately(atRate: speed)
        }
        updateNowPlaying()

        guard !track.isLive else { return }
        let asset = item.asset
        Task {
            let loaded = try? await asset.load(.duration)
            guard token == self.loadToken, let loaded else { return }
            let seconds = loaded.seconds
            if seconds.isFinite, seconds > 0 {
                self.duration = seconds
                self.updateNowPlaying()
            }
        }
    }

    private func activateSession() {
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playback, mode: .spokenAudio, options: [])
        try? session.setActive(true)
    }

    private func observePlayer() {
        let interval = CMTime(seconds: 0.5, preferredTimescale: 600)
        timeObserver = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            let seconds = time.seconds
            Task { @MainActor in
                guard let self, seconds.isFinite else { return }
                self.currentTime = seconds
            }
        }

        statusObservation = player.observe(\.timeControlStatus, options: [.new]) { [weak self] _, _ in
            Task { @MainActor in
                guard let self else { return }
                let status = self.player.timeControlStatus
                self.isPlaying = status == .playing
                self.isBuffering = status == .waitingToPlayAtSpecifiedRate
                self.updateNowPlaying()
            }
        }

        let center = NotificationCenter.default
        observers.append(center.addObserver(forName: .AVPlayerItemDidPlayToEndTime, object: nil, queue: .main) { [weak self] note in
            let finished = note.object as? AVPlayerItem
            Task { @MainActor in
                guard let self, finished === self.player.currentItem else { return }
                if self.hasNext {
                    self.next()
                } else {
                    self.wantsPlayback = false
                    self.player.seek(to: .zero)
                    self.currentTime = 0
                    self.updateNowPlaying()
                }
            }
        })

        observers.append(center.addObserver(forName: AVAudioSession.interruptionNotification, object: nil, queue: .main) { [weak self] note in
            let info = note.userInfo
            let typeValue = info?[AVAudioSessionInterruptionTypeKey] as? UInt
            let optionsValue = info?[AVAudioSessionInterruptionOptionKey] as? UInt ?? 0
            Task { @MainActor in
                guard let self, let typeValue,
                      let type = AVAudioSession.InterruptionType(rawValue: typeValue)
                else { return }
                if type == .ended,
                   AVAudioSession.InterruptionOptions(rawValue: optionsValue).contains(.shouldResume),
                   self.wantsPlayback {
                    self.resume()
                }
            }
        })
    }

    private func configureRemoteCommands() {
        let commands = MPRemoteCommandCenter.shared()

        commands.playCommand.addTarget { [weak self] _ in
            Task { @MainActor in self?.resume() }
            return .success
        }
        commands.pauseCommand.addTarget { [weak self] _ in
            Task { @MainActor in self?.pause() }
            return .success
        }
        commands.togglePlayPauseCommand.addTarget { [weak self] _ in
            Task { @MainActor in self?.toggle() }
            return .success
        }
        commands.skipForwardCommand.preferredIntervals = [30]
        commands.skipForwardCommand.addTarget { [weak self] _ in
            Task { @MainActor in self?.skip(by: 30) }
            return .success
        }
        commands.skipBackwardCommand.preferredIntervals = [15]
        commands.skipBackwardCommand.addTarget { [weak self] _ in
            Task { @MainActor in self?.skip(by: -15) }
            return .success
        }
        commands.changePlaybackPositionCommand.addTarget { [weak self] event in
            guard let event = event as? MPChangePlaybackPositionCommandEvent else {
                return .commandFailed
            }
            let position = event.positionTime
            Task { @MainActor in self?.seek(to: position) }
            return .success
        }
    }

    private func updateNowPlaying() {
        guard let current else {
            MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
            return
        }
        var info: [String: Any] = [
            MPMediaItemPropertyTitle: current.title,
            MPMediaItemPropertyArtist: current.subtitle.isEmpty ? GSR.name : current.subtitle,
            MPMediaItemPropertyAlbumTitle: GSR.name,
            MPNowPlayingInfoPropertyIsLiveStream: current.isLive,
            MPNowPlayingInfoPropertyPlaybackRate: isPlaying ? Double(current.isLive ? 1 : speed) : 0.0,
            MPNowPlayingInfoPropertyElapsedPlaybackTime: currentTime
        ]
        if duration > 0, !current.isLive {
            info[MPMediaItemPropertyPlaybackDuration] = duration
        }
        if let art = UIImage(named: "NowPlayingArt") {
            info[MPMediaItemPropertyArtwork] = MPMediaItemArtwork(boundsSize: art.size) { _ in art }
        }
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info

        let commands = MPRemoteCommandCenter.shared()
        commands.skipForwardCommand.isEnabled = canSeek
        commands.skipBackwardCommand.isEnabled = canSeek
        commands.changePlaybackPositionCommand.isEnabled = canSeek
    }
}

extension Double {
    /// "4:07" or "1:02:33".
    var clockString: String {
        guard isFinite, self >= 0 else { return "0:00" }
        let total = Int(self.rounded(.down))
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let seconds = total % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        }
        return String(format: "%d:%02d", minutes, seconds)
    }
}
