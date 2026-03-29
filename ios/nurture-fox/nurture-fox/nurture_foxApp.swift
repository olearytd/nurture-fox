import SwiftUI
import SwiftData
import CoreData
import CloudKit

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        application.registerForRemoteNotifications()

        // Perform data migration on first launch
        DataMigrationHelper.migrateIfNeeded()

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

    // Use Core Data instead of SwiftData
    @StateObject private var coreDataManager = CoreDataManager.shared

    // Track joining state for the partner
    @State private var isJoiningFamily = false

    var body: some Scene {
        WindowGroup {
            ZStack {
                ContentView()
                    .environment(\.managedObjectContext, coreDataManager.container.viewContext)
                    .environmentObject(coreDataManager)
                    .preferredColorScheme(scheme)
                    .disabled(isJoiningFamily)

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
    }

    // --- ACCEPTANCE LOGIC ---
    private func acceptInvitation(url: URL) {
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
