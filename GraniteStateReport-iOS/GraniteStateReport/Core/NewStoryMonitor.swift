import BackgroundTasks
import Foundation
import UserNotifications

/// New-story alerts without a push server. iOS wakes the app in the background from time to time;
/// the app checks the site for stories newer than the last one the reader saw and posts a local
/// notification. iOS decides the timing, so alerts can trail publication.
enum NewStoryMonitor {
    static let alertsEnabledKey = "alertsEnabled"
    private static let lastSeenKey = "lastSeenStoryDate"

    static var alertsEnabled: Bool {
        UserDefaults.standard.bool(forKey: alertsEnabledKey)
    }

    /// Asks iOS for permission to show alerts. Returns whether the reader allowed it.
    static func requestPermission() async -> Bool {
        let center = UNUserNotificationCenter.current()
        let granted = (try? await center.requestAuthorization(options: [.alert, .sound])) ?? false
        return granted
    }

    static func isAuthorized() async -> Bool {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            return true
        default:
            return false
        }
    }

    /// Queues the next background check. Safe to call often; the newest request replaces the last.
    static func scheduleNextCheck() {
        guard alertsEnabled else {
            BGTaskScheduler.shared.cancel(taskRequestWithIdentifier: GSR.refreshTaskID)
            return
        }
        let request = BGAppRefreshTaskRequest(identifier: GSR.refreshTaskID)
        request.earliestBeginDate = Date(timeIntervalSinceNow: 30 * 60)
        try? BGTaskScheduler.shared.submit(request)
    }

    /// Records the newest story the reader has had on screen, so it is never announced.
    static func markSeen(_ articles: [Article]) {
        guard let newest = articles.map(\.date).max() else { return }
        let stamp = newest.timeIntervalSince1970
        if stamp > UserDefaults.standard.double(forKey: lastSeenKey) {
            UserDefaults.standard.set(stamp, forKey: lastSeenKey)
        }
    }

    /// Runs in the background. Posts one notification when there is something new.
    static func checkForNewStories() async {
        guard alertsEnabled, await isAuthorized() else { return }
        guard let latest = try? await WordPressAPI.shared.posts(page: 1, perPage: 5).articles,
              !latest.isEmpty
        else { return }

        let lastSeen = UserDefaults.standard.double(forKey: lastSeenKey)
        defer { markSeen(latest) }
        // First run: set the baseline and stay quiet.
        guard lastSeen > 0 else { return }

        let fresh = latest
            .filter { $0.date.timeIntervalSince1970 > lastSeen }
            .sorted { $0.date > $1.date }
        guard let lead = fresh.first else { return }

        let content = UNMutableNotificationContent()
        content.title = fresh.count == 1 ? GSR.name : "\(fresh.count) new stories"
        content.body = lead.title
        content.sound = .default
        content.threadIdentifier = "new-stories"
        content.userInfo = ["postID": lead.id]

        let request = UNNotificationRequest(identifier: "story-\(lead.id)", content: content, trigger: nil)
        try? await UNUserNotificationCenter.current().add(request)
    }
}
