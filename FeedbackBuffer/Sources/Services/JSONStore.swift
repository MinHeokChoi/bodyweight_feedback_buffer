import Foundation

protocol FileStore {
    func load<T: Decodable>(_ type: T.Type, from filename: String) throws -> T?
    func save<T: Encodable>(_ value: T, to filename: String) throws
}

final class JSONStore: FileStore {
    private let directory: URL
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    init(directory: URL? = nil) {
        if let directory {
            self.directory = directory
        } else {
            self.directory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        }
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        self.encoder = encoder

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        self.decoder = decoder
    }

    private func url(for filename: String) -> URL {
        directory.appendingPathComponent(filename)
    }

    func load<T: Decodable>(_ type: T.Type, from filename: String) throws -> T? {
        let fileURL = url(for: filename)
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return nil
        }
        let data = try Data(contentsOf: fileURL)
        return try decoder.decode(T.self, from: data)
    }

    func save<T: Encodable>(_ value: T, to filename: String) throws {
        let fileURL = url(for: filename)
        try FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        let data = try encoder.encode(value)
        try data.write(to: fileURL, options: [.atomic])
    }
}
