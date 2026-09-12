import Foundation
import Observation

@MainActor
@Observable
final class WarmupStore {
    private(set) var warmup: [WarmupItem] = []
    private(set) var warmupSessions: [WarmupSession] = []
    private(set) var selectedWarmupSessionId: UUID?
    private(set) var defaultWarmupSessionId: UUID?

    private let warmupRepository: WarmupRepository
    private let persistenceScheduler: PersistenceScheduler
    private let reportIssue: (PersistenceIssue) -> Void
    private var currentWarmupDateKey = WarmupDateKey.today()

    init(
        warmupRepository: WarmupRepository = WarmupRepository(),
        persistenceScheduler: PersistenceScheduler = .background,
        reportIssue: @escaping (PersistenceIssue) -> Void = { _ in }
    ) {
        self.warmupRepository = warmupRepository
        self.persistenceScheduler = persistenceScheduler
        self.reportIssue = reportIssue
        bootstrap()
    }

    // MARK: - Bootstrap

    private func bootstrap() {
        currentWarmupDateKey = WarmupDateKey.today()
        bootstrapWarmupSessions()
        warmup = loadWarmup(for: .now)
    }

    private func bootstrapWarmupSessions() {
        do {
            if let sessions = try warmupRepository.loadSessions(), !sessions.isEmpty {
                warmupSessions = sessions
                let storedSelected = warmupRepository.loadSelectedSessionId()
                selectedWarmupSessionId = sessions.contains(where: { $0.id == storedSelected })
                    ? storedSelected
                    : sessions.first?.id
                let storedDefault = warmupRepository.loadDefaultSessionId()
                defaultWarmupSessionId = sessions.contains(where: { $0.id == storedDefault })
                    ? storedDefault
                    : nil
                return
            }
        } catch {
            AppLog.persistence.error("warmup sessions load failed: \(error.localizedDescription, privacy: .public)")
            reportPersistenceIssue(
                title: "웜업 세션을 불러오지 못했습니다",
                error: error,
                recovery: "기본 웜업 세션으로 시작합니다."
            )
        }

        let legacyRoutine: [WarmupItem]
        do {
            legacyRoutine = try warmupRepository.legacyLoadRoutine() ?? DefaultWarmup.items
        } catch {
            legacyRoutine = DefaultWarmup.items
        }
        let normalizedItems = legacyRoutine.map { WarmupItem(id: $0.id, label: $0.label) }
        let initialSession = WarmupSession(name: DefaultWarmupSession.initialName, items: normalizedItems)
        warmupSessions = [initialSession]
        selectedWarmupSessionId = initialSession.id
        defaultWarmupSessionId = initialSession.id

        let legacyDaily = warmupRepository.legacyLoadDailyState(for: .now)
        if !legacyDaily.isEmpty {
            warmupRepository.save(legacyDaily, sessionId: initialSession.id, for: .now)
        }

        do {
            try warmupRepository.saveSessions(warmupSessions)
        } catch {
            AppLog.persistence.error("warmup sessions seed save failed: \(error.localizedDescription, privacy: .public)")
            reportPersistenceIssue(
                title: "웜업 세션을 저장하지 못했습니다",
                error: error,
                recovery: "기본 세션은 메모리에서 사용할 수 있어요. 다시 시도하면 저장됩니다."
            )
        }
        warmupRepository.saveSelectedSessionId(initialSession.id)
        warmupRepository.saveDefaultSessionId(initialSession.id)
    }

    private func loadWarmup(for date: Date) -> [WarmupItem] {
        guard let session = currentWarmupSession else { return [] }
        let saved = warmupRepository.load(sessionId: session.id, for: date)
        return session.items.map { base in
            var item = base
            item.checked = saved[base.id] ?? false
            return item
        }
    }

    // MARK: - Session state

    var currentWarmupSession: WarmupSession? {
        guard let id = selectedWarmupSessionId else { return nil }
        return warmupSessions.first { $0.id == id }
    }

    var isCurrentSessionDefault: Bool {
        guard let selectedWarmupSessionId, let defaultWarmupSessionId else { return false }
        return selectedWarmupSessionId == defaultWarmupSessionId
    }

    // MARK: - Warmup intents

    func toggleWarmup(_ id: String) {
        guard let index = warmup.firstIndex(where: { $0.id == id }) else { return }
        warmup[index].checked.toggle()
        persistWarmupChecks()
    }

    func setWarmupChecked(_ id: String, checked: Bool) {
        guard let index = warmup.firstIndex(where: { $0.id == id }) else { return }
        guard warmup[index].checked != checked else { return }
        warmup[index].checked = checked
        persistWarmupChecks()
    }

    func resetWarmupToday() {
        warmup = warmup.map { WarmupItem(id: $0.id, label: $0.label) }
        guard let sessionId = selectedWarmupSessionId else { return }
        warmupRepository.reset(sessionId: sessionId, for: .now)
    }

    func addWarmupItem(label: String) {
        let trimmed = label.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty,
              let sessionIndex = currentSessionIndex() else { return }
        let item = WarmupItem(id: "custom_\(UUID().uuidString)", label: trimmed)
        warmupSessions[sessionIndex].items.append(item)
        warmup.append(item)
        persistWarmupSessions()
    }

    func updateWarmupItem(id: String, label: String) {
        let trimmed = label.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty,
              let sessionIndex = currentSessionIndex(),
              let itemIndex = warmupSessions[sessionIndex].items.firstIndex(where: { $0.id == id }) else { return }
        warmupSessions[sessionIndex].items[itemIndex].label = trimmed
        if let warmupIndex = warmup.firstIndex(where: { $0.id == id }) {
            warmup[warmupIndex].label = trimmed
        }
        persistWarmupSessions()
    }

    func deleteWarmupItem(_ id: String) {
        guard let sessionIndex = currentSessionIndex() else { return }
        let beforeCount = warmupSessions[sessionIndex].items.count
        warmupSessions[sessionIndex].items.removeAll { $0.id == id }
        guard warmupSessions[sessionIndex].items.count != beforeCount else { return }
        warmup.removeAll { $0.id == id }
        persistWarmupSessions()
        persistWarmupChecks()
    }

    func moveWarmupItem(fromOffsets source: IndexSet, toOffset destination: Int) {
        guard !source.isEmpty, let sessionIndex = currentSessionIndex() else { return }
        moveItems(&warmupSessions[sessionIndex].items, fromOffsets: source, toOffset: destination)
        moveItems(&warmup, fromOffsets: source, toOffset: destination)
        persistWarmupSessions()
        persistWarmupChecks()
    }

    func resetWarmupRoutine() {
        guard isCurrentSessionDefault, let sessionIndex = currentSessionIndex() else { return }
        warmupSessions[sessionIndex].items = DefaultWarmup.items
        warmup = DefaultWarmup.items
        persistWarmupSessions()
        warmupRepository.reset(sessionId: warmupSessions[sessionIndex].id, for: .now)
    }

    @discardableResult
    func addWarmupSession(name: String, items: [WarmupItem]) -> WarmupSession {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let resolvedName = trimmedName.isEmpty ? "새 웜업" : trimmedName
        let normalizedItems = items.map { WarmupItem(id: $0.id, label: $0.label) }
        let session = WarmupSession(name: resolvedName, items: normalizedItems)
        warmupSessions.append(session)
        persistWarmupSessions()
        selectWarmupSession(session.id)
        return session
    }

    func renameWarmupSession(id: UUID, name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty,
              let index = warmupSessions.firstIndex(where: { $0.id == id }) else { return }
        guard warmupSessions[index].name != trimmed else { return }
        warmupSessions[index].name = trimmed
        persistWarmupSessions()
    }

    func deleteWarmupSession(_ id: UUID) {
        guard warmupSessions.count > 1,
              let index = warmupSessions.firstIndex(where: { $0.id == id }) else { return }
        warmupSessions.remove(at: index)
        warmupRepository.deleteAllCheckStates(forSessionId: id)
        if selectedWarmupSessionId == id {
            let nextId = warmupSessions.first?.id
            selectedWarmupSessionId = nextId
            if let nextId {
                warmupRepository.saveSelectedSessionId(nextId)
            }
            warmup = loadWarmup(for: .now)
        }
        persistWarmupSessions()
    }

    func selectWarmupSession(_ id: UUID) {
        guard warmupSessions.contains(where: { $0.id == id }) else { return }
        guard selectedWarmupSessionId != id else { return }
        selectedWarmupSessionId = id
        warmupRepository.saveSelectedSessionId(id)
        warmup = loadWarmup(for: .now)
    }

    var warmupCompletionRatio: Double {
        guard !warmup.isEmpty else { return 0 }
        let done = warmup.filter(\.checked).count
        return Double(done) / Double(warmup.count)
    }

    var isWarmupComplete: Bool {
        !warmup.isEmpty && warmup.allSatisfy(\.checked)
    }

    func refreshWarmupIfNeeded(now: Date = .now, force: Bool = false) {
        let nextKey = WarmupDateKey.today(now)
        guard force || nextKey != currentWarmupDateKey else { return }
        currentWarmupDateKey = nextKey
        warmup = loadWarmup(for: now)
    }

    // MARK: - Persistence

    private func currentSessionIndex() -> Int? {
        guard let id = selectedWarmupSessionId else { return nil }
        return warmupSessions.firstIndex { $0.id == id }
    }

    private func persistWarmupChecks() {
        guard let sessionId = selectedWarmupSessionId else { return }
        let state = Dictionary(uniqueKeysWithValues: warmup.map { ($0.id, $0.checked) })
        warmupRepository.save(state, sessionId: sessionId, for: .now)
    }

    private func persistWarmupSessions() {
        let snapshot = warmupSessions
        let repository = warmupRepository
        scheduleSave(
            { try repository.saveSessions(snapshot) },
            failureTitle: "웜업 세션을 저장하지 못했습니다"
        )
    }

    private func scheduleSave(
        _ work: @escaping () throws -> Void,
        failureTitle: String
    ) {
        persistenceScheduler.perform { [weak self] in
            do {
                try work()
            } catch {
                AppLog.persistence.error("save failed: \(failureTitle, privacy: .public) — \(error.localizedDescription, privacy: .public)")
                Task { @MainActor in
                    self?.reportPersistenceIssue(
                        title: failureTitle,
                        error: error,
                        recovery: "앱을 종료하기 전에 저장 공간과 파일 권한을 확인해 주세요."
                    )
                }
            }
        }
    }

    private func reportPersistenceIssue(title: String, error: Error, recovery: String) {
        reportIssue(
            PersistenceIssue(
                title: title,
                message: "\(recovery)\n\n원인: \(error.localizedDescription)"
            )
        )
    }
}
