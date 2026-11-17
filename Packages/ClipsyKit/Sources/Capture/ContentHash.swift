import CryptoKit
import Foundation
import Store

func contentHash(of representations: [Representation]) -> Data {
    let sorted = representations.sorted {
        $0.uti == $1.uti ? $0.data.lexicographicallyPrecedes($1.data) : $0.uti < $1.uti
    }
    var hasher = SHA256()
    for representation in sorted {
        let uti = Data(representation.uti.utf8)
        for field in [uti, representation.data] {
            withUnsafeBytes(of: UInt64(field.count).littleEndian) { hasher.update(bufferPointer: $0) }
            hasher.update(data: field)
        }
    }
    return Data(hasher.finalize())
}
