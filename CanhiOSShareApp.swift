import SwiftUI

extension Notification.Name {
    static let openMakeToolsFile = Notification.Name("openMakeToolsFile")
}

@main
struct CheatiOSShareApp: App {
    @StateObject private var appState = AppState()
    @StateObject private var patchDraftCoordinator = PatchDraftCoordinator()
    @AppStorage(AppLanguage.storageKey) private var languageCode = AppLanguage.vietnamese.rawValue

    private var language: AppLanguage {
        AppLanguage(rawValue: languageCode) ?? .english
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
                .environmentObject(patchDraftCoordinator)
                .environment(\.appLanguage, language)
                .environment(\.locale, language.locale)
                .onAppear {
                    appState.detectSupport()
                    appState.runExploit()
                    PatchProjectLibrary.migrateRemoveLegacyFiles()
                    _ = BackgroundAudioKeepAlive.shared  // init observers
                }
                .onOpenURL { url in
                    MakeToolsStore.shared.load(url: url)
                    NotificationCenter.default.post(name: .openMakeToolsFile, object: nil)
                }
        }
    }
}
