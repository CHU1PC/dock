import Foundation

struct TrashDropFailure: Equatable {
    let name: String
    let message: String
}

enum TrashDropService {
    static func move(_ urls: [URL], using trashItem: (URL) throws -> Void) -> [TrashDropFailure] {
        urls.compactMap { url in
            do {
                try trashItem(url)
                return nil
            } catch {
                return TrashDropFailure(name: url.lastPathComponent, message: error.localizedDescription)
            }
        }
    }
}
