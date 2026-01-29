//
//  CreateEventView.swift
//  SemtioApp
//
//  Copyright © 2026 Oğuzhan Çankaya ve Fikir Creative. All rights reserved.
//

import SwiftUI

struct CreateEventView: View {
    @Environment(\.presentationMode) var presentationMode
    
    // Form States
    @State private var eventDescription: String = ""
    @State private var selectedGender: String = "Herkes"
    @State private var minAge: Int = 18
    @State private var maxAge: Int = 99
    @State private var selectedType: String? = nil
    @State private var otherType: String = ""
    
    let genderOptions = ["Herkes", "Erkek", "Kadın"]
    
    let eventTypes = [
        ("Night Club", "moon.stars.fill"),
        ("Vücut Geliştirme", "dumbbell.fill"),
        ("Kahve", "cup.and.saucer.fill"),
        ("Sahil Yürüyüşü", "figure.walk"),
        ("Koşu", "figure.run"),
        ("Müzik", "music.note"),
        ("Sanat", "paintpalette.fill"),
        ("Sinema", "film.fill"),
        ("Tiyatro", "theatermasks.fill"),
        ("Yazılım", "laptopcomputer"),
        ("Oyun", "gamecontroller.fill"),
        ("Yemek", "fork.knife"),
        ("Seyahat", "airplane"),
        ("Kamp", "tent.fill"),
        ("Yoga", "figure.mind.and.body"),
        ("Dans", "music.quarternote.3"),
        ("Fotoğrafçılık", "camera.fill"),
        ("Kitap", "book.fill"),
        ("Networking", "person.2.fill"),
        ("Parti", "party.popper.fill")
    ]
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                
                // 1. Event Picture
                Button(action: {
                    // Placeholder for Image Picker
                }) {
                    VStack {
                        Image(systemName: "camera.fill")
                            .font(.system(size: 30))
                            .foregroundColor(.semtioPrimary)
                        Text("Kapak Fotoğrafı Ekle")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.semtioPrimary)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 150)
                    .background(Color.semtioPrimary.opacity(0.1))
                    .cornerRadius(16)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(style: StrokeStyle(lineWidth: 2, dash: [5]))
                            .foregroundColor(.semtioPrimary.opacity(0.5))
                    )
                }
                .padding(.horizontal)
                
                // 2. Event Description
                VStack(alignment: .leading, spacing: 8) {
                    Text("Etkinlik Açıklaması")
                        .font(.headline)
                        .foregroundColor(.semtioDarkText)
                    
                    TextEditor(text: $eventDescription)
                        .frame(height: 100)
                        .padding(8)
                        .background(Color.white)
                        .cornerRadius(12)
                        .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(AppColor.textSecondary.opacity(0.2), lineWidth: 1)
                        )
                }
                .padding(.horizontal)
                
                // 3. Who Can Join (Sex)
                VStack(alignment: .leading, spacing: 8) {
                    Text("Kimler Katılabilir?")
                        .font(.headline)
                        .foregroundColor(.semtioDarkText)
                    
                    Picker("Cinsiyet", selection: $selectedGender) {
                        ForEach(genderOptions, id: \.self) { option in
                            Text(option)
                        }
                    }
                    .pickerStyle(SegmentedPickerStyle())
                }
                .padding(.horizontal)
                
                // 4. Age Range
                VStack(alignment: .leading, spacing: 12) {
                    Text("Yaş Aralığı: \(minAge) - \(maxAge)")
                        .font(.headline)
                        .foregroundColor(.semtioDarkText)
                    
                    HStack {
                        Text("Min: \(minAge)")
                            .foregroundColor(.gray)
                        Stepper("", value: $minAge, in: 18...maxAge)
                        
                        Spacer()
                        
                        Text("Max: \(maxAge)")
                            .foregroundColor(.gray)
                        Stepper("", value: $maxAge, in: minAge...99)
                    }
                    .padding()
                    .background(Color.white)
                    .cornerRadius(12)
                    .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
                }
                .padding(.horizontal)
                
                // 5. Event Type Selection
                VStack(alignment: .leading, spacing: 12) {
                    Text("Etkinlik Türü")
                        .font(.headline)
                        .foregroundColor(.semtioDarkText)
                    
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 100))], spacing: 12) {
                        ForEach(eventTypes, id: \.0) { type in
                            EventTypeCard(
                                title: type.0,
                                icon: type.1,
                                isSelected: selectedType == type.0,
                                action: { selectedType = type.0 }
                            )
                        }
                    }
                    
                    // Other Type
                    VStack(alignment: .leading) {
                        Text("Diğer")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                        
                        TextField("Buraya yazın...", text: $otherType)
                            .padding()
                            .background(Color.white)
                            .cornerRadius(12)
                            .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
                    }
                    .padding(.top, 8)
                }
                .padding(.horizontal)
                
                // Create Button
                Button(action: {
                    // Action to create event
                    presentationMode.wrappedValue.dismiss()
                }) {
                    Text("Etkinliği Yayınla")
                        .font(.headline)
                        .foregroundColor(AppColor.onPrimary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(Color.semtioPrimary)
                        .cornerRadius(28)
                        .shadow(color: .semtioPrimary.opacity(0.3), radius: 10, x: 0, y: 5)
                }
                .padding(.horizontal)
                .padding(.bottom, 30)
            }
            .padding(.top, 20)
        }
        .background(Color.semtioBackground)
        .navigationTitle("Etkinlik Oluştur")
    }
}

struct EventTypeCard: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(isSelected ? .white : .semtioPrimary)
                
                Text(title)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(isSelected ? .white : .semtioDarkText)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 80)
            .background(isSelected ? Color.semtioPrimary : Color.white)
            .cornerRadius(12)
            .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color.clear : AppColor.textSecondary.opacity(0.1), lineWidth: 1)
            )
        }
    }
}
