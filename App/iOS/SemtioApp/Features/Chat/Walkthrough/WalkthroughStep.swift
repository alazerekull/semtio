//
//  WalkthroughStep.swift
//  SemtioApp
//
//  Copyright © 2026 Oğuzhan Çankaya ve Fikir Creative. All rights reserved.
//

import SwiftUI

enum TooltipPosition {
    case above
    case below
    case center
}

struct WalkthroughStep: Identifiable, Equatable {
    let id: Int
    let title: String
    let description: String
    let icon: String
    let spotlightPadding: CGFloat
    let tooltipPosition: TooltipPosition

    static func == (lhs: WalkthroughStep, rhs: WalkthroughStep) -> Bool {
        lhs.id == rhs.id
    }
}

extension WalkthroughStep {
    static let chatSteps: [WalkthroughStep] = [
        WalkthroughStep(
            id: 0,
            title: "Mesajlar'a Hoş Geldin!",
            description: "Sohbet bölümünün yeni özelliklerini keşfet.",
            icon: "bubble.left.and.bubble.right.fill",
            spotlightPadding: 0,
            tooltipPosition: .center
        ),
        WalkthroughStep(
            id: 1,
            title: "Filtre Sekmeleri",
            description: "Sohbetlerini kategorilere göre filtrele: Tümü, Okunmamış, Gruplar, Arşiv ve Gizli.",
            icon: "line.3.horizontal.decrease.circle.fill",
            spotlightPadding: 8,
            tooltipPosition: .below
        ),
        WalkthroughStep(
            id: 2,
            title: "Gizli Sohbetler",
            description: "Özel sohbetlerini PIN korumalı klasörde sakla. İlk erişimde şifre belirlenir.",
            icon: "lock.fill",
            spotlightPadding: 6,
            tooltipPosition: .below
        ),
        WalkthroughStep(
            id: 3,
            title: "Sağa Kaydır: Gizle",
            description: "Bir sohbeti sağa kaydırarak Gizli sekmesine taşı.",
            icon: "hand.point.right.fill",
            spotlightPadding: 8,
            tooltipPosition: .above
        ),
        WalkthroughStep(
            id: 4,
            title: "Sola Kaydır: Arşivle & Sil",
            description: "Sola kaydırarak sohbeti arşivle veya sil.",
            icon: "hand.point.left.fill",
            spotlightPadding: 8,
            tooltipPosition: .above
        ),
        WalkthroughStep(
            id: 5,
            title: "Hazırsın!",
            description: "Artık sohbet özelliklerini biliyorsun. İyi sohbetler!",
            icon: "checkmark.circle.fill",
            spotlightPadding: 0,
            tooltipPosition: .center
        )
    ]
}
