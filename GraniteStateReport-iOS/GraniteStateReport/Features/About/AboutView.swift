import SwiftUI
import UIKit

/// About the publication, how to reach it, and the app's few settings.
struct AboutView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @AppStorage(NewStoryMonitor.alertsEnabledKey) private var alertsEnabled = false

    @State private var browserPage: BrowserPage?
    @State private var showsPermissionHelp = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    VStack(spacing: 10) {
                        Image("Masthead")
                            .resizable()
                            .scaledToFit()
                            .frame(maxWidth: 280)
                            .accessibilityLabel(GSR.name)
                        Text(GSR.tagline)
                            .font(.gsrSerif(15, bold: false, relativeTo: .subheadline))
                            .italic()
                            .foregroundStyle(Color.gsrMuted)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                }

                Section {
                    Toggle("New story alerts", isOn: alertsBinding)
                } header: {
                    Text("Alerts")
                } footer: {
                    Text("The app checks the site for new stories in the background. iOS decides when that happens, so an alert can arrive some time after a story is published.")
                }

                Section("Send us something") {
                    pageRow("Send a Tip", slug: "tips", icon: "envelope.badge")
                    pageRow("Tell Us Your Story", slug: "share-your-story", icon: "text.bubble")
                    Button {
                        openURL(GSR.emailURL)
                    } label: {
                        Label(GSR.email, systemImage: "envelope")
                    }
                    Button {
                        openURL(GSR.phoneURL)
                    } label: {
                        Label(GSR.phoneDisplay, systemImage: "phone")
                    }
                }

                Section("About Granite State Report") {
                    pageRow("About", slug: "about", icon: "info.circle")
                    pageRow("Mission Statement", slug: "mission", icon: "flag")
                    pageRow("The Constitution of Granite State Report", slug: "constitution", icon: "scroll")
                    pageRow("Code of Ethics", slug: "code-of-ethics", icon: "checkmark.seal")
                    pageRow("How Granite State Report Is Made", slug: "how-this-is-made", icon: "hammer")
                    pageRow("Editor", slug: "editor", icon: "person")
                }

                Section("Corrections") {
                    pageRow("Corrections Register", slug: "corrections", icon: "list.bullet.clipboard")
                    pageRow("Corrections Policy", slug: "corrections-policy", icon: "doc.text")
                }

                Section {
                    Button {
                        openURL(GSR.page("support"))
                    } label: {
                        Label("Support Granite State Report", systemImage: "heart")
                    }
                } footer: {
                    Text("Opens in Safari.")
                }

                Section("Legal") {
                    pageRow("Privacy Policy", slug: "privacy-policy", icon: "hand.raised")
                    pageRow("Terms of Use", slug: "terms-of-use", icon: "doc.plaintext")
                    pageRow("Accessibility", slug: "accessibility", icon: "accessibility")
                }

                Section {
                    LabeledContent("Version", value: appVersion)
                } footer: {
                    Text("This app reads the public site. It has no accounts, no ads and no tracking of its own. Pages opened from the site follow the site\u{2019}s Privacy Policy.")
                }
            }
            .navigationTitle("About")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .fullScreenCover(item: $browserPage) { page in
                SafariView(url: page.url)
                    .ignoresSafeArea()
            }
            .alert("Alerts are turned off", isPresented: $showsPermissionHelp) {
                Button("Open Settings") {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        openURL(url)
                    }
                }
                Button("Not Now", role: .cancel) {}
            } message: {
                Text("Allow notifications for this app in Settings to get new story alerts.")
            }
        }
        .tint(Color.gsrBrick)
    }

    private func pageRow(_ title: String, slug: String, icon: String) -> some View {
        Button {
            browserPage = BrowserPage(url: GSR.page(slug))
        } label: {
            Label(title, systemImage: icon)
        }
    }

    private var alertsBinding: Binding<Bool> {
        Binding(
            get: { alertsEnabled },
            set: { wantsAlerts in
                guard wantsAlerts else {
                    alertsEnabled = false
                    NewStoryMonitor.scheduleNextCheck()
                    return
                }
                Task {
                    let allowed = await NewStoryMonitor.requestPermission()
                    alertsEnabled = allowed
                    showsPermissionHelp = !allowed
                    NewStoryMonitor.scheduleNextCheck()
                }
            }
        )
    }

    private var appVersion: String {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = info?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }
}
