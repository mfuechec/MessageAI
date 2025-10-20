import Foundation
import FirebaseFirestore

/// Firestore encoder/decoder extensions for transparent Date ↔ Timestamp conversion
extension Firestore.Encoder {
    /// Default encoder with timestamp strategy
    static var `default`: Firestore.Encoder {
        let encoder = Firestore.Encoder()
        encoder.dateEncodingStrategy = .timestamp
        return encoder
    }
}

extension Firestore.Decoder {
    /// Default decoder with timestamp strategy
    static var `default`: Firestore.Decoder {
        let decoder = Firestore.Decoder()
        decoder.dateDecodingStrategy = .timestamp
        return decoder
    }
}

