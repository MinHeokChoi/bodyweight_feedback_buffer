import XCTest
@testable import FeedbackBuffer

final class InMemoryFileStore: FileStore {
    private var storage: [String: Data] = [:]
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    init() {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        self.encoder = encoder
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        self.decoder = decoder
    }

    func load<T: Decodable>(_ type: T.Type, from filename: String) throws -> T? {
        guard let data = storage[filename] else { return nil }
        return try decoder.decode(T.self, from: data)
    }

    func save<T: Encodable>(_ value: T, to filename: String) throws {
        let data = try encoder.encode(value)
        storage[filename] = data
    }

    func seed(_ data: Data, to filename: String) {
        storage[filename] = data
    }

    func rawData(for filename: String) -> Data? {
        storage[filename]
    }
}

final class FailingFileStore: FileStore {
    enum TestError: LocalizedError {
        case failed

        var errorDescription: String? {
            "테스트 저장소 실패"
        }
    }

    func load<T: Decodable>(_ type: T.Type, from filename: String) throws -> T? {
        throw TestError.failed
    }

    func save<T: Encodable>(_ value: T, to filename: String) throws {
        throw TestError.failed
    }
}

@MainActor
class StoreTestCase: XCTestCase {
    private var suiteName: String {
        "FeedbackBufferTests.\(String(describing: type(of: self)))"
    }

    var defaults: UserDefaults!

    override func setUp() {
        super.setUp()
        UserDefaults().removePersistentDomain(forName: suiteName)
        defaults = UserDefaults(suiteName: suiteName)
    }

    override func tearDown() {
        UserDefaults().removePersistentDomain(forName: suiteName)
        defaults = nil
        super.tearDown()
    }

    func makeFeedbackStore(fileStore: FileStore = InMemoryFileStore()) -> FeedbackStore {
        FeedbackStore(
            feedbackRepository: FeedbackRepository(store: fileStore),
            settingsRepository: UserSettingsRepository(defaults: defaults),
            persistenceScheduler: .immediate
        )
    }

    func makeWarmupStore() -> WarmupStore {
        WarmupStore(
            warmupRepository: WarmupRepository(defaults: defaults),
            persistenceScheduler: .immediate
        )
    }

    func makeContainer(fileStore: FileStore = InMemoryFileStore()) -> AppContainer {
        AppContainer(
            feedbackRepository: FeedbackRepository(store: fileStore),
            warmupRepository: WarmupRepository(defaults: defaults),
            settingsRepository: UserSettingsRepository(defaults: defaults),
            persistenceScheduler: .immediate
        )
    }

    @discardableResult
    func addFeedback(
        to store: FeedbackStore,
        title: String = "라인 유지",
        importance: Int = 3
    ) -> Feedback {
        let skill = store.skills.first!
        store.addFeedback(skill: skill, title: title, note: "", importance: importance)
        return store.feedbacks.last!
    }
}
