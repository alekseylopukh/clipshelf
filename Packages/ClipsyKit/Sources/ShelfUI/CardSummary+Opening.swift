import Foundation
import Store

extension CardSummary {
    func openableURLs(in representations: [Representation]) -> [URL] {
        switch kind {
        case .link:
            guard let url = decodedMetadata.url else { return [] }
            return URL(string: url).map { [$0] } ?? []
        case .file:
            return representations
                .filter { $0.uti == "public.file-url" }
                .compactMap { URL(dataRepresentation: $0.data, relativeTo: nil) }
                .map { ($0 as NSURL).filePathURL ?? $0 }
        case .text, .image, .color, .unknown:
            return []
        }
    }
}
