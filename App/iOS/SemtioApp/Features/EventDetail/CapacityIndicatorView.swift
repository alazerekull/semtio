//
//  CapacityIndicatorView.swift
//  SemtioApp
//
//  Copyright © 2026 Oğuzhan Çankaya ve Fikir Creative. All rights reserved.
//

import SwiftUI

struct CapacityIndicatorView: View {
    let participantCount: Int
    let capacityLimit: Int
    
    var progress: Double {
        guard capacityLimit > 0 else { return 0 }
        return min(1.0, Double(participantCount) / Double(capacityLimit))
    }
    
    var isFull: Bool { participantCount >= capacityLimit }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Kontenjan")
                    .font(.caption)
                    .foregroundColor(.semtioGrayText)
                Spacer()
                Text("\(participantCount)/\(capacityLimit)")
                    .font(.caption)
                    .foregroundColor(isFull ? .red : .semtioGrayText)
            }
            
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(AppColor.textSecondary.opacity(0.15))
                        .frame(height: 10)
                    RoundedRectangle(cornerRadius: 6)
                        .fill(isFull ? Color.red : Color.semtioPrimary)
                        .frame(width: geo.size.width * progress, height: 10)
                }
            }
            .frame(height: 10)
            
            if isFull {
                Text("ETKİNLİK DOLU")
                    .font(.caption2)
                    .bold()
                    .foregroundColor(.red)
            }
        }
        .padding()
        .background(Color.white)
        .cornerRadius(14)
        .shadow(color: .black.opacity(0.03), radius: 6, x: 0, y: 2)
    }
}
