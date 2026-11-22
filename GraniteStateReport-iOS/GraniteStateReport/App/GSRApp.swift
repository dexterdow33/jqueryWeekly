import SwiftUI

@main
struct GSRApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @Environment(\.scenePhase) private var scenePhase

    @State private var library = Library()
    @State private var sections = SectionStore()
    @State private var router = Router.shared
    @State private var player = AudioPlayer.shared

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(library)
                .environment(sections)
                .environment(router)
                .environment(player)
                .tint(Color.gsrBrick)
                .task { await sections.load() }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .background {
                NewStoryMonitor.scheduleNextCheck()
            }
        }
        .backgroundTask(.appRefresh(GSR.refreshTaskID)) {
            NewStoryMonitor.scheduleNextCheck()
            await NewStoryMonitor.checkForNewStories()
        }
    }
}
