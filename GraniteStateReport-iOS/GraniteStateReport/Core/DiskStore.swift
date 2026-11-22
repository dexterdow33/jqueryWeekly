import Foundation

/// JSON files on disk. `documents` holds what the reader chose to keep (saved stories);
/// `caches` holds what the app can always fetch again (the last feed).
struct DiskStore {
    static let documents = DiskStore(directory: .applicationSupportDirectory)
    static let caches = DiskStore(directory: .cachesDirectory)

    private let directory: FileManager.SearchPathDirectory

    private func url(for name: String) -> URL? {
        guard let base = FileManager.default.urls(for: directory, in: .userDomainMask).first else {
            return nil
        }
        let folder = base.appendingPathComponent("GSR", isDirectory: true)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        return folder.appendingPathComponent(name + ".json")
    }

    func load<T: Decodable>(_ type: T.Type, named name: String) -> T? {
        guard let url = url(for: name), let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(type, from: data)
    }

    func save<T: Encodable>(_ value: T, named name: String) {
        guard let url = url(for: name), let data = try? JSONEncoder().encode(value) else { return }
        try? data.write(to: url, options: .atomic)
    }
}
