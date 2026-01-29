//
//  SessionManager.swift
//  SemtioApp
//
//  Copyright © 2026 Oğuzhan Çankaya ve Fikir Creative. All rights reserved.
//

import Foundation
import Combine
import SwiftUI

enum SessionState {
    case unknown
    case signedOut
    case signedIn
}

@MainActor
final class SessionManager: ObservableObject {
    @Published var state: SessionState = .unknown
    
    // We will inject this from AppState
    var auth: AuthManager?
    var cancellables = Set<AnyCancellable>()
    
    func bootstrap() async {
        guard let auth = auth else {
            print("SessionManager: AuthManager not injected")
            self.state = .signedOut
            return
        }
        
        // Let AuthManager restore existing session state
        auth.bootstrap()
        
        // Subscribe to future changes
        auth.$uid
            .receive(on: RunLoop.main)
            .sink { [weak self] uid in
                self?.state = (uid != nil) ? .signedIn : .signedOut
            }
            .store(in: &cancellables)
    }
    
    func signOut() {
        Task {
            await auth?.signOut()
            await MainActor.run {
                self.state = .signedOut
            }
        }
    }
}
