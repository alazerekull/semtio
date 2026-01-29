
import Foundation
import FirebaseFirestore

extension PostSharePreview {
    var dictionary: [String: Any] {
        return [
            "id": id ?? "",
            "authorId": authorId ?? "",
            "authorName": authorName ?? "",
            "authorUsername": authorUsername ?? "",
            "authorAvatarURL": authorAvatarURL ?? "",
            "caption": caption ?? "",
            "mediaURL": mediaURL ?? "",
            "mediaType": mediaType ?? 0,
            "aspectRatio": aspectRatio ?? 1.0
        ]
    }
}

extension EventSharePreview {
    var dictionary: [String: Any] {
        var dict: [String: Any] = [
            "id": id,
            "title": title,
            "dateLabel": dateLabel
        ]
        
        if let locationName = locationName { dict["locationName"] = locationName }
        if let coverImageURL = coverImageURL { dict["coverImageURL"] = coverImageURL }
        if let categoryIcon = categoryIcon { dict["categoryIcon"] = categoryIcon }
        
        return dict
    }
}

extension ChatMessage {
    var dictionary: [String: Any] {
        var dict: [String: Any] = [
            "id": id,
            "threadId": threadId,
            "text": text,
            "senderId": senderId,
            "createdAt": createdAt,
            "type": type.rawValue
        ]
        
        if let clientTimestamp = clientTimestamp {
            dict["clientTimestamp"] = clientTimestamp
        }
        
        if let attachmentURL = attachmentURL {
            dict["attachmentURL"] = attachmentURL
        }
        
        if let sharedPostId = sharedPostId {
            dict["sharedPostId"] = sharedPostId
        }
        
        if let postPreview = postPreview {
            dict["postPreview"] = postPreview.dictionary
        }
        
        if let sharedEventId = sharedEventId {
            dict["sharedEventId"] = sharedEventId
        }
        
        if let eventPreview = eventPreview {
            dict["eventPreview"] = eventPreview.dictionary
        }
        
        return dict
    }
}
