//
//  Array+Extensions.swift
//  SemtioApp
//
//  Created by Antigravity on 2026-01-29.
//

import Foundation

extension Array {
    func chunked(into size: Int) -> [[Element]] {
        return stride(from: 0, to: count, by: size).map {
            Array(self[$0 ..< Swift.min($0 + size, count)])
        }
    }
}
