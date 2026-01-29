import Foundation
#if canImport(FirebaseFunctions)
import FirebaseFunctions

final class CloudFunctionsClient {
    static let shared = CloudFunctionsClient()

    private let functions: Functions

    private init() {
        self.functions = Functions.functions(region: "europe-west3")
        // Uncomment to use emulator
        // functions.useEmulator(withHost: "localhost", port: 5001)
    }

    /// Calls a HTTPS Callable Cloud Function
    /// - Parameters:
    ///   - name: The name of the function (e.g. "joinEvent")
    ///   - data: The payload dictionary
    /// - Returns: The result data (usually a dictionary)
    func call(_ name: String, _ data: [String: Any]) async throws -> Any? {
        let result = try await functions.httpsCallable(name).call(data)
        return result.data
    }
}
#endif
