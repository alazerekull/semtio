//
//  PostUploadError.swift
//  SemtioApp
//
//  Created by Semtio AI on 2026-01-19.
//  Copyright © 2026 Oğuzhan Çankaya ve Fikir Creative. All rights reserved.
//

import Foundation

enum PostUploadError: LocalizedError {
    case notAuthenticated
    case imageCompressionFailed
    case uploadFailed(Error)
    case urlFetchFailed
    case firestoreWriteFailed(Error)
    case unknown
    
    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "Oturumunuz bulunamadı. Lütfen tekrar giriş yapın."
        case .imageCompressionFailed:
            return "Fotoğraf işlenirken bir hata oluştu. Lütfen başka bir resim deneyin."
        case .uploadFailed(_):
            return "Fotoğraf sunucuya yüklenirken hata oluştu. İnternet bağlantınızı kontrol edip tekrar deneyin."
        case .urlFetchFailed:
            return "Fotoğraf bağlantısı alınamadı. Lütfen tekrar deneyin."
        case .firestoreWriteFailed(_):
            return "Paylaşım oluşturulurken veritabanı hatası oluştu."
        case .unknown:
            return "Bilinmeyen bir hata oluştu. Lütfen daha sonra tekrar deneyin."
        }
    }
}
