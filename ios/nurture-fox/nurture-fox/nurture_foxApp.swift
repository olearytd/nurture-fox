import SwiftUI
import SwiftData
import CloudKit

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        application.registerForRemoteNotifications()
        return true
    }

    func application(_ application: UIApplication,
                     didReceiveRemoteNotification userInfo: [AnyHashable : Any],
                     fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        if let _ = CKNotification(fromRemoteNotificationDictionary: userInfo) {
            completionHandler(.newData)
        } else {
            completionHandler(.noData)
        }
    }
}

@main
struct nurture_foxApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    @AppStorage("themePreference") private var themePreference: Int = 0
    
    // NEW: Track joining state for the partner
    @State private var isJoiningFamily = false

    var sharedModelContainer: ModelContainer = {
        let groupID = "group.toleary.nurture-fox"
        let schema = Schema([
            BabyEvent.self,
            Milestone.self
        ])
        
        let modelConfiguration = ModelConfiguration(
            groupContainer: .identifier(groupID),
            cloudKitDatabase: .automatic
        )

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ZStack {
                ContentView()
                    .preferredColorScheme(scheme)
                    .disabled(isJoiningFamily) // Prevent interaction while joining
                
                // --- JOINING SPINNER ---
                if isJoiningFamily {
                    Color.black.opacity(0.4)
                        .ignoresSafeArea()
                    VStack(spacing: 20) {
                        ProgressView()
                            .scaleEffect(1.5)
                            .tint(.white)
                        Text("Joining Family...")
                            .font(.headline)
                            .foregroundColor(.white)
                    }
                    .padding(40)
                    .background(RoundedRectangle(cornerRadius: 20).fill(Color(.systemGray6).opacity(0.8)))
                }
            }
            .onOpenURL { url in
                acceptInvitation(url: url)
            }
        }
        .modelContainer(sharedModelContainer)
    }

    // --- ACCEPTANCE LOGIC ---
    private func acceptInvitation(url: URL) {
        // Use explicit container to match SettingsView
        let container = CKContainer(identifier: "iCloud.com.toleary.nurturefox")
        isJoiningFamily = true
        
        let fetchMetadataOp = CKFetchShareMetadataOperation(shareURLs: [url])
        fetchMetadataOp.perShareMetadataBlock = { shareURL, metadata, error in
            if let metadata = metadata {
                let acceptOp = CKAcceptSharesOperation(shareMetadatas: [metadata])
                acceptOp.acceptSharesResultBlock = { result in
                    DispatchQueue.main.async {
                        isJoiningFamily = false
                        switch result {
                        case .success:
                            print("Successfully joined the partner's family share!")
                        case .failure(let error):
                            print("Error accepting share: \(error.localizedDescription)")
                        }
                    }
                }
                container.add(acceptOp)
            } else {
                DispatchQueue.main.async {
                    isJoiningFamily = false
                    print("Error fetching metadata: \(error?.localizedDescription ?? "Unknown error")")
                }
            }
        }
        container.add(fetchMetadataOp)
    }
    
    var scheme: ColorScheme? {
        switch themePreference {
        case 1: return .light
        case 2: return .dark
        default: return nil
        }
    }
}
