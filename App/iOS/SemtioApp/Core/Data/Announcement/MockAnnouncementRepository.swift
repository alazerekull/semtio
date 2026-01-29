//
//  MockAnnouncementRepository.swift
//  SemtioApp
//
//  Copyright © 2026 Oğuzhan Çankaya ve Fikir Creative. All rights reserved.
//

import Foundation

final class MockAnnouncementRepository: AnnouncementRepositoryProtocol {
    
    private var announcements: [Announcement] = []
    
    init() {
        // Seed mock data
        announcements = [
            Announcement(
                id: "ann1",
                title: "Semtio v2.0 Yayında! 🎉",
                body: """
                Merhaba Semtio ailesi!
                
                Yeni sürümümüzle birlikte pek çok yenilik sunuyoruz:
                
                • Arkadaş arama ve ekleme özelliği
                • Semtlere göre etkinlik filtreleme
                • Özel etkinlikler bölümü
                • Paylaşım kodu ile kolay bağlantı
                • Instagram tarzı profil sayfası
                • DM tarzı sohbet deneyimi
                
                Geri bildirimlerinizi bekliyoruz!
                
                — Semtio Ekibi
                """,
                createdAt: Date(),
                isActive: true,
                actionURL: URL(string: "https://semtio.app/whats-new")
            ),
            Announcement(
                id: "ann2",
                title: "Hafta Sonu Etkinlik Yarışması 🏆",
                body: """
                Bu hafta sonu en çok katılımcı çeken etkinliği oluşturan kullanıcıya özel ödüller!
                
                Katılım şartları:
                1. Etkinlik oluştur
                2. En az 10 katılımcı topla
                3. Etkinliğini #SemtioHaftaSonu etiketiyle paylaş
                
                Kazanana Semtio Premium 1 yıllık üyelik hediye!
                """,
                createdAt: Date().addingTimeInterval(-86400),
                isActive: true,
                actionURL: nil
            ),
            Announcement(
                id: "ann3",
                title: "Bakım Çalışması (Eski)",
                body: "Bu duyuru artık aktif değil.",
                createdAt: Date().addingTimeInterval(-604800),
                isActive: false,
                actionURL: nil
            )
        ]
    }
    
    func fetchActiveAnnouncements() async throws -> [Announcement] {
        try? await Task.sleep(nanoseconds: 200_000_000)
        return announcements.filter { $0.isActive }.sorted { $0.createdAt > $1.createdAt }
    }
    
    func fetchLatestAnnouncement() async throws -> Announcement? {
        try? await Task.sleep(nanoseconds: 100_000_000)
        return announcements.filter { $0.isActive }.sorted { $0.createdAt > $1.createdAt }.first
    }
    
    func fetchAnnouncement(id: String) async throws -> Announcement? {
        try? await Task.sleep(nanoseconds: 100_000_000)
        return announcements.first { $0.id == id }
    }
}
