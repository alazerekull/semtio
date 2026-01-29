//
//  LocationPermissionView.swift
//  SemtioApp
//
//  Copyright © 2026 Oğuzhan Çankaya ve Fikir Creative. All rights reserved.
//

import SwiftUI
import CoreLocation

struct LocationPermissionView: View {
    var status: CLAuthorizationStatus
    var requestAction: () -> Void
    
    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            
            Image(systemName: "location.circle.fill")
                .font(.system(size: 72))
                .foregroundColor(.semtioPrimary) // Uses app theme color
            
            VStack(spacing: 8) {
                Text(titleText)
                    .font(.title2)
                    .bold()
                
                Text(descriptionText)
                    .multilineTextAlignment(.center)
                    .font(.body)
                    .foregroundColor(.gray)
                    .padding(.horizontal)
            }
            
            Button(action: handleAction) {
                Text(buttonText)
                    .font(.headline)
                    .foregroundColor(AppColor.onPrimary)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.semtioPrimary)
                    .cornerRadius(16)
            }
            .padding(.horizontal, 40)
            
            Spacer()
        }
        .background(Color.semtioBackground)
    }
    
    // MARK: - Dynamic Content
    
    var titleText: String {
        switch status {
        case .denied, .restricted:
            return "Konum İzni Kapalı"
        default:
            return "Konum İzni Gerekli"
        }
    }
    
    var descriptionText: String {
        switch status {
        case .denied, .restricted:
            return "Etkinlikleri haritada görmek için lütfen Ayarlar'dan konum iznini etkinleştirin."
        default:
            return "Çevrenizdeki etkinlikleri haritada görebilmek için konum iznine ihtiyacımız var."
        }
    }
    
    var buttonText: String {
        switch status {
        case .denied, .restricted:
            return "Ayarlara Git"
        default:
            return "Konumu Aç"
        }
    }
    
    func handleAction() {
        if status == .denied || status == .restricted {
            if let url = URL(string: UIApplication.openSettingsURLString) {
                UIApplication.shared.open(url)
            }
        } else {
            requestAction()
        }
    }
}
