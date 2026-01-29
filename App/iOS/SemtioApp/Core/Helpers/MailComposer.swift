//
//  MailComposer.swift
//  SemtioApp
//
//  Copyright © 2026 Oğuzhan Çankaya ve Fikir Creative. All rights reserved.
//

import SwiftUI
import MessageUI

struct MailComposer: UIViewControllerRepresentable {
    @Binding var isPresented: Bool
    var recipients: [String]
    var subject: String
    var body: String
    
    class Coordinator: NSObject, MFMailComposeViewControllerDelegate {
        @Binding var isPresented: Bool
        
        init(isPresented: Binding<Bool>) {
            _isPresented = isPresented
        }
        
        func mailComposeController(_ controller: MFMailComposeViewController, didFinishWith result: MFMailComposeResult, error: Error?) {
            isPresented = false
        }
    }
    
    func makeCoordinator() -> Coordinator {
        return Coordinator(isPresented: $isPresented)
    }
    
    func makeUIViewController(context: Context) -> MFMailComposeViewController {
        let vc = MFMailComposeViewController()
        vc.mailComposeDelegate = context.coordinator
        vc.setToRecipients(recipients)
        vc.setSubject(subject)
        vc.setMessageBody(body, isHTML: false)
        return vc
    }
    
    func updateUIViewController(_ uiViewController: MFMailComposeViewController, context: Context) {
        // No updates needed
    }
    
    /// Helper to check if device is configured for mail
    static func canSendMail() -> Bool {
        return MFMailComposeViewController.canSendMail()
    }
}
