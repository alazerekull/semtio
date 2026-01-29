//
//  ProfileCompletionView.swift
//  SemtioApp
//
//  Copyright © 2026 Oğuzhan Çankaya ve Fikir Creative. All rights reserved.
//

import SwiftUI

struct ProfileCompletionView: View {
    @EnvironmentObject var userStore: UserStore
    @EnvironmentObject var session: SessionManager
    
    @State private var fullName: String = ""
    @State private var username: String = ""
    @State private var city: String = "İstanbul"
    @State private var bio: String = ""
    @State private var isViewAppeared: Bool = false
    
    // Sample static interests
    let availableInterests = ["Teknoloji", "Sanat", "Spor", "Müzik", "Yemek", "Seyahat"]
    @State private var selectedInterests: [String] = []
    
    // Validation
    var isValid: Bool {
        !fullName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        username.count >= 3 &&
        !username.contains(" ") &&
        !city.isEmpty
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Kişisel Bilgiler")) {
                    TextField("Ad Soyad", text: $fullName)
                    TextField("Kullanıcı Adı (@username)", text: $username)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                    
                    Picker("Şehir", selection: $city) {
                        Text("İstanbul").tag("İstanbul")
                        Text("Ankara").tag("Ankara")
                        Text("İzmir").tag("İzmir")
                        Text("Antalya").tag("Antalya")
                    }
                }
                
                Section(header: Text("Hakkında")) {
                    TextField("Kısa Biyografi (İsteğe bağlı)", text: $bio)
                }
                
                Section(header: Text("İlgi Alanları")) {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack {
                            ForEach(availableInterests, id: \.self) { interest in
                                InterestChip(
                                    title: interest,
                                    isSelected: selectedInterests.contains(interest),
                                    action: {
                                        if selectedInterests.contains(interest) {
                                            selectedInterests.removeAll { $0 == interest }
                                        } else {
                                            selectedInterests.append(interest)
                                        }
                                    }
                                )
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
                
                Section {
                    Button(action: {
                        Task {
                            await userStore.completeProfile(
                                fullName: fullName,
                                username: username,
                                city: city,
                                bio: bio.isEmpty ? nil : bio,
                                interests: selectedInterests
                            )
                        }
                    }) {
                        Text("Devam Et")
                            .frame(maxWidth: .infinity)
                            .foregroundColor(AppColor.onPrimary)
                    }
                    .disabled(!isValid)
                    .listRowBackground(isValid ? Color.semtioPrimary : AppColor.textSecondary.opacity(0.3))
                }
            }
            .navigationTitle("Profilini Tamamla")
            .onAppear {
                // Pre-fill existing name if available
                fullName = userStore.currentUser.fullName
                
                // Trigger animation
                withAnimation(.easeOut(duration: 0.8)) {
                    isViewAppeared = true
                }
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: {
                        session.signOut()
                    }) {
                        Text("Çıkış Yap")
                            .foregroundColor(.red)
                    }
                }
            }
        }
        .opacity(isViewAppeared ? 1 : 0)
        .offset(y: isViewAppeared ? 0 : 20)
    }
}

struct InterestChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Text(title)
            .font(.caption)
            .fontWeight(.medium)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(isSelected ? Color.semtioPrimary : AppColor.textSecondary.opacity(0.1))
            .foregroundColor(isSelected ? .white : .black)
            .cornerRadius(16)
            .onTapGesture {
                withAnimation {
                    action()
                }
            }
    }
}
