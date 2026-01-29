
import FirebaseCore
import FirebaseFirestore

enum FirestoreDiagnostic {

    static func debugUsersCollection() async {
        guard let app = FirebaseApp.app() else {
            print("❌ FirebaseApp not configured")
            return
        }

        let options = app.options
        print("🔥 FIREBASE PROJECT ID:", options.projectID ?? "nil")
        print("🔥 FIREBASE DATABASE URL:", options.databaseURL ?? "nil")

        let db = Firestore.firestore()
        let settings = db.settings
        print("🔥 FIRESTORE HOST:", settings.host)
        print("🔥 FIRESTORE SSL ENABLED:", settings.isSSLEnabled)

        do {
            let snap = try await db.collection("users").limit(to: 10).getDocuments()
            print("🧪 USERS SAMPLE COUNT:", snap.documents.count)

            for doc in snap.documents {
                let data = doc.data()
                print("""
                👤 USER DOC:
                  id: \(doc.documentID)
                  displayName: \(data["displayName"] ?? "nil")
                  username: \(data["username"] ?? "nil")
                  usernameLower: \(data["usernameLower"] ?? "nil")
                  shareCode11: \(data["shareCode11"] ?? "nil")
                """)
            }
        } catch {
            print("❌ USERS SAMPLE QUERY FAILED:", error.localizedDescription)
        }
    }

    static func runDiagnostic() async {
        await debugUsersCollection()
    }
}
