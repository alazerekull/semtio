//
//  StoryViewersSheet.swift
//  SemtioApp
//
//  Copyright © 2026 Oğuzhan Çankaya ve Fikir Creative. All rights reserved.
//

import SwiftUI

struct StoryViewersSheet: View {
    let story: Story
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var storyStore: StoryStore

    @State private var viewers: [StoryViewer] = []
    @State private var isLoading = true

    var body: some View {
        NavigationView {
            List {
                Section {
                    HStack {
                        Image(systemName: "eye.fill")
                        Text("\(story.viewCount) Görüntüleme")
                            .bold()
                        Spacer()
                    }
                    .foregroundColor(.secondary)
                }

                if isLoading {
                    HStack {
                        Spacer()
                        ProgressView()
                        Spacer()
                    }
                    .padding()
                } else if viewers.isEmpty {
                    HStack {
                        Spacer()
                        VStack(spacing: 8) {
                            Image(systemName: "eye.slash")
                                .font(.largeTitle)
                                .foregroundColor(.gray.opacity(0.5))
                            Text("Henüz kimse görmedi")
                                .foregroundColor(.gray)
                        }
                        Spacer()
                    }
                    .padding(.vertical, 40)
                } else {
                    ForEach(viewers) { viewer in
                        HStack(spacing: 12) {
                            // Avatar
                            if let avatarURL = viewer.viewerAvatar, let url = URL(string: avatarURL) {
                                AsyncImage(url: url) { image in
                                    image.resizable().scaledToFill()
                                } placeholder: {
                                    Circle().fill(Color.gray.opacity(0.3))
                                }
                                .frame(width: 44, height: 44)
                                .clipShape(Circle())
                            } else {
                                Circle()
                                    .fill(Color.gray.opacity(0.3))
                                    .frame(width: 44, height: 44)
                                    .overlay(
                                        Image(systemName: "person.fill")
                                            .foregroundColor(.gray)
                                    )
                            }

                            // Name & Time
                            VStack(alignment: .leading, spacing: 2) {
                                Text(viewer.viewerName ?? "Kullanıcı")
                                    .font(.subheadline.bold())
                                    .foregroundColor(.primary)

                                if let date = viewer.viewedAt {
                                    Text(timeAgoString(from: date))
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }

                            Spacer()

                            // Reaction (if any)
                            if let reaction = viewer.reaction, !reaction.isEmpty {
                                Text(reaction)
                                    .font(.title2)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("İzleyenler")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Kapat") {
                        dismiss()
                    }
                }
            }
            .task {
                await loadViewers()
            }
        }
    }

    func loadViewers() async {
        isLoading = true
        viewers = await storyStore.fetchViewers(for: story)
        isLoading = false
    }

    func timeAgoString(from date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.locale = Locale(identifier: "tr_TR")
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

// Temporary Mock for compilation if AppUser doesn't have mock
extension AppUser {
    static var mock: AppUser {
        let json = """
        {
            "id": "mock1",
            "fullName": "Test User",
            "username": "testuser",
            "friends": 0,
            "friendIds": [],
            "eventsCreated": [],
            "savedEventIds": []
        }
        """.data(using: .utf8)!
        
        do {
            return try JSONDecoder().decode(AppUser.self, from: json)
        } catch {
            print("Mock User Decode Error: \(error)")
            // Fallback to a minimal init if possible, or crash (it's a mock)
            // Trying a minimal memberwise init just in case JSON fails (unlikely)
            // But since memberwise is hard, we rely on JSON.
            fatalError("Failed to create mock user")
        }
    }
}
