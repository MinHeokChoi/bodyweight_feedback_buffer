import Foundation
import Observation

struct PersistenceScheduler {
    let perform: (@escaping () -> Void) -> Void

    static let background: PersistenceScheduler = {
        let queue = DispatchQueue(label: "com.feedbackbuffer.persistence", qos: .utility)
        return PersistenceScheduler { queue.async(execute: $0) }
    }()

    static let immediate = PersistenceScheduler { $0() }
}

@MainActor
@Observable
final class AppStore {
    struct PersistenceIssue: Identifiable {
        let id = UUID()
        let title: String
        let message: String
    }

    private(set) var feedbacks: [Feedback] = [] {
        didSet { recomputeFeedbackDerivatives() }
    }
    private(set) var skills: [Skill] = []
    private(set) var warmup: [WarmupItem] = []
    private(set) var warmupSessions: [WarmupSession] = []
    private(set) var selectedWarmupSessionId: UUID?
    private(set) var defaultWarmupSessionId: UUID?
    private(set) var quickPhrases: [String] = []
    private(set) var hasCompletedOnboarding = false
    private(set) var persistenceIssue: PersistenceIssue?

    private(set) var unarchivedFeedbacksScored: [(Feedback, Double)] = []
    private(set) var unarchivedCountsBySkill: [UUID: Int] = [:]
    private(set) var feedbackCountsBySkill: [UUID: Int] = [:]
    private(set) var lastActivityBySkill: [UUID: Date] = [:]

    private let feedbackRepository: FeedbackRepository
    private let warmupRepository: WarmupRepository
    private let settingsRepository: UserSettingsRepository
    private let persistenceScheduler: PersistenceScheduler
    private var currentWarmupDateKey = WarmupDateKey.today()

    private static let feedbackSchemaVersion = 1

    init(
        feedbackRepository: FeedbackRepository = FeedbackRepository(),
        warmupRepository: WarmupRepository = WarmupRepository(),
        settingsRepository: UserSettingsRepository = UserSettingsRepository(),
        persistenceScheduler: PersistenceScheduler = .background
    ) {
        self.feedbackRepository = feedbackRepository
        self.warmupRepository = warmupRepository
        self.settingsRepository = settingsRepository
        self.persistenceScheduler = persistenceScheduler
        bootstrap()
    }

    // MARK: - Bootstrap

    private func bootstrap() {
        let didCompleteOnboarding = settingsRepository.loadHasCompletedOnboarding()
        hasCompletedOnboarding = didCompleteOnboarding
        quickPhrases = settingsRepository.loadQuickPhrases()
        currentWarmupDateKey = WarmupDateKey.today()

        do {
            var loadedSkills = try feedbackRepository.loadSkills()
            let loadedFeedbacks = try feedbackRepository.loadFeedbacks()

            let seededDefaults = loadedSkills.isEmpty
            if seededDefaults {
                loadedSkills = SampleData.defaultSkills()
            } else if DefaultSkillNormalizer.normalize(&loadedSkills) {
                try feedbackRepository.saveSkills(loadedSkills)
            }

            let validSkillIds = Set(loadedSkills.map(\.id))
            let prunedFeedbacks = loadedFeedbacks.filter { validSkillIds.contains($0.skillId) }
            let didPruneOrphans = prunedFeedbacks.count != loadedFeedbacks.count

            let priorSchemaVersion = settingsRepository.loadFeedbackSchemaVersion()
            let needsMigrationFlush = priorSchemaVersion < Self.feedbackSchemaVersion && !prunedFeedbacks.isEmpty

            skills = loadedSkills
            feedbacks = prunedFeedbacks

            if seededDefaults {
                persistSkills()
            }
            if didPruneOrphans || needsMigrationFlush {
                persistFeedbacks()
            }
            if priorSchemaVersion < Self.feedbackSchemaVersion {
                settingsRepository.saveFeedbackSchemaVersion(Self.feedbackSchemaVersion)
            }

            if !didCompleteOnboarding && !prunedFeedbacks.isEmpty {
                completeOnboarding()
            }
            AppLog.lifecycle.info("bootstrap ok skills=\(loadedSkills.count) feedbacks=\(prunedFeedbacks.count) pruned=\(didPruneOrphans)")
        } catch {
            skills = SampleData.defaultSkills()
            feedbacks = []
            AppLog.persistence.error("bootstrap failed: \(error.localizedDescription, privacy: .public)")
            reportPersistenceIssue(
                title: "데이터를 불러오지 못했습니다",
                error: error,
                recovery: "기본 기술 목록으로 시작합니다. 기존 기록 파일을 확인한 뒤 다시 시도해 주세요."
            )
        }

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

    // MARK: - Derived

    var unarchivedFeedbacks: [Feedback] {
        unarchivedFeedbacksScored.map(\.0)
    }

    var topFeedback: Feedback? { unarchivedFeedbacksScored.first?.0 }

    func unarchivedFeedbacksScored(forSkillId skillId: UUID) -> [(Feedback, Double)] {
        unarchivedFeedbacksScored.filter { $0.0.skillId == skillId }
    }

    func unarchivedCount(forSkillId skillId: UUID) -> Int {
        unarchivedCountsBySkill[skillId] ?? 0
    }

    func feedbackCount(forSkillId skillId: UUID) -> Int {
        feedbackCountsBySkill[skillId] ?? 0
    }

    private func recomputeFeedbackDerivatives() {
        unarchivedFeedbacksScored = FeedbackScoring.sortedUnarchivedWithScores(feedbacks)
        var unarchived: [UUID: Int] = [:]
        var all: [UUID: Int] = [:]
        var last: [UUID: Date] = [:]
        for feedback in feedbacks {
            all[feedback.skillId, default: 0] += 1
            if feedback.archivedAt == nil {
                unarchived[feedback.skillId, default: 0] += 1
            }
            let d = feedback.referenceDate
            if let cur = last[feedback.skillId] {
                if d > cur { last[feedback.skillId] = d }
            } else {
                last[feedback.skillId] = d
            }
        }
        unarchivedCountsBySkill = unarchived
        feedbackCountsBySkill = all
        lastActivityBySkill = last
    }

    func hasSkill(named name: String) -> Bool {
        let normalizedName = normalizedSkillName(name)
        guard !normalizedName.isEmpty else { return false }
        return skills.contains { normalizedSkillName($0.name) == normalizedName }
    }

    // MARK: - Feedback intents

    func addFeedback(
        skill: Skill,
        title: String,
        note: String,
        importance: Int,
        category: FeedbackCategory = .skill
    ) {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let new = Feedback(
            skillId: skill.id,
            skillName: skill.name,
            title: trimmed,
            note: note.trimmingCharacters(in: .whitespacesAndNewlines),
            importance: importance,
            category: category
        )
        feedbacks.append(new)
        persistFeedbacks()
    }

    func updateFeedback(_ updated: Feedback) {
        guard let idx = feedbacks.firstIndex(where: { $0.id == updated.id }) else { return }
        var copy = updated
        copy.updatedAt = .now
        feedbacks[idx] = copy
        persistFeedbacks()
    }

    func archive(_ id: UUID) {
        guard let idx = feedbacks.firstIndex(where: { $0.id == id }) else { return }
        feedbacks[idx].archivedAt = .now
        feedbacks[idx].updatedAt = .now
        persistFeedbacks()
    }

    func unarchive(_ id: UUID) {
        guard let idx = feedbacks.firstIndex(where: { $0.id == id }) else { return }
        guard feedbacks[idx].archivedAt != nil else { return }
        feedbacks[idx].archivedAt = nil
        feedbacks[idx].updatedAt = .now
        persistFeedbacks()
    }

    func markPracticed(_ id: UUID) {
        guard let idx = feedbacks.firstIndex(where: { $0.id == id }) else { return }
        feedbacks[idx].unresolvedCount += 1
        feedbacks[idx].lastReviewedAt = .now
        feedbacks[idx].updatedAt = .now
        persistFeedbacks()
    }

    func delete(_ id: UUID) {
        feedbacks.removeAll { $0.id == id }
        persistFeedbacks()
    }

    // MARK: - Skill intents

    @discardableResult
    func addSkill(name: String, symbolName: String = "dumbbell.fill") -> Bool {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty,
              !hasSkill(named: trimmed) else { return false }
        skills.append(Skill(name: trimmed, symbolName: symbolName))
        persistSkills()
        return true
    }

    func updateSkill(id: UUID, name: String, symbolName: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty,
              let idx = skills.firstIndex(where: { $0.id == id }) else { return }

        skills[idx].name = trimmed
        skills[idx].symbolName = symbolName

        var didUpdateFeedbacks = false
        for feedbackIdx in feedbacks.indices where feedbacks[feedbackIdx].skillId == id {
            feedbacks[feedbackIdx].skillName = trimmed
            didUpdateFeedbacks = true
        }

        persistSkills()
        if didUpdateFeedbacks {
            persistFeedbacks()
        }
    }

    func deleteSkill(_ id: UUID) {
        let beforeCount = skills.count
        skills.removeAll { $0.id == id }
        guard skills.count != beforeCount else { return }

        let feedbacksBeforeDelete = feedbacks.count
        feedbacks.removeAll { $0.skillId == id }

        persistSkills()
        if feedbacks.count != feedbacksBeforeDelete {
            persistFeedbacks()
        }
    }

    func moveSkill(fromOffsets source: IndexSet, toOffset destination: Int) {
        guard !source.isEmpty else { return }
        moveItems(&skills, fromOffsets: source, toOffset: destination)
        persistSkills()
    }

    // MARK: - Warmup intents

    var currentWarmupSession: WarmupSession? {
        guard let id = selectedWarmupSessionId else { return nil }
        return warmupSessions.first { $0.id == id }
    }

    var isCurrentSessionDefault: Bool {
        guard let selectedWarmupSessionId, let defaultWarmupSessionId else { return false }
        return selectedWarmupSessionId == defaultWarmupSessionId
    }

    func toggleWarmup(_ id: String) {
        guard let idx = warmup.firstIndex(where: { $0.id == id }) else { return }
        warmup[idx].checked.toggle()
        persistWarmupChecks()
    }

    func setWarmupChecked(_ id: String, checked: Bool) {
        guard let idx = warmup.firstIndex(where: { $0.id == id }) else { return }
        guard warmup[idx].checked != checked else { return }
        warmup[idx].checked = checked
        persistWarmupChecks()
    }

    func resetWarmupToday() {
        warmup = warmup.map {
            WarmupItem(id: $0.id, label: $0.label)
        }
        guard let sessionId = selectedWarmupSessionId else { return }
        warmupRepository.reset(sessionId: sessionId, for: .now)
    }

    func addWarmupItem(label: String) {
        let trimmed = label.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty,
              let sessionIdx = currentSessionIndex() else { return }
        let item = WarmupItem(id: "custom_\(UUID().uuidString)", label: trimmed)
        warmupSessions[sessionIdx].items.append(item)
        warmup.append(item)
        persistWarmupSessions()
    }

    func updateWarmupItem(id: String, label: String) {
        let trimmed = label.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty,
              let sessionIdx = currentSessionIndex(),
              let itemIdx = warmupSessions[sessionIdx].items.firstIndex(where: { $0.id == id }) else { return }
        warmupSessions[sessionIdx].items[itemIdx].label = trimmed
        if let warmupIdx = warmup.firstIndex(where: { $0.id == id }) {
            warmup[warmupIdx].label = trimmed
        }
        persistWarmupSessions()
    }

    func deleteWarmupItem(_ id: String) {
        guard let sessionIdx = currentSessionIndex() else { return }
        let beforeCount = warmupSessions[sessionIdx].items.count
        warmupSessions[sessionIdx].items.removeAll { $0.id == id }
        guard warmupSessions[sessionIdx].items.count != beforeCount else { return }
        warmup.removeAll { $0.id == id }
        persistWarmupSessions()
        persistWarmupChecks()
    }

    func moveWarmupItem(fromOffsets source: IndexSet, toOffset destination: Int) {
        guard !source.isEmpty, let sessionIdx = currentSessionIndex() else { return }
        moveItems(&warmupSessions[sessionIdx].items, fromOffsets: source, toOffset: destination)
        moveItems(&warmup, fromOffsets: source, toOffset: destination)
        persistWarmupSessions()
        persistWarmupChecks()
    }

    func resetWarmupRoutine() {
        guard isCurrentSessionDefault, let sessionIdx = currentSessionIndex() else { return }
        warmupSessions[sessionIdx].items = DefaultWarmup.items
        warmup = DefaultWarmup.items
        persistWarmupSessions()
        warmupRepository.reset(sessionId: warmupSessions[sessionIdx].id, for: .now)
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
              let idx = warmupSessions.firstIndex(where: { $0.id == id }) else { return }
        guard warmupSessions[idx].name != trimmed else { return }
        warmupSessions[idx].name = trimmed
        persistWarmupSessions()
    }

    func deleteWarmupSession(_ id: UUID) {
        guard warmupSessions.count > 1,
              let idx = warmupSessions.firstIndex(where: { $0.id == id }) else { return }
        warmupSessions.remove(at: idx)
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

    private func currentSessionIndex() -> Int? {
        guard let id = selectedWarmupSessionId else { return nil }
        return warmupSessions.firstIndex { $0.id == id }
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

    // MARK: - Quick phrases

    func updateQuickPhrases(_ phrases: [String]) {
        quickPhrases = phrases
        do {
            try settingsRepository.saveQuickPhrases(phrases)
        } catch {
            reportPersistenceIssue(
                title: "빠른 문구를 저장하지 못했습니다",
                error: error,
                recovery: "잠시 후 다시 시도해 주세요."
            )
        }
    }

    // MARK: - Onboarding

    func completeOnboarding() {
        hasCompletedOnboarding = true
        settingsRepository.saveHasCompletedOnboarding()
    }

    func clearPersistenceIssue() {
        persistenceIssue = nil
    }

    // MARK: - Persistence

    private func persistFeedbacks() {
        let snapshot = feedbacks
        let repo = feedbackRepository
        scheduleSave(
            { try repo.saveFeedbacks(snapshot) },
            failureTitle: "피드백을 저장하지 못했습니다"
        )
    }

    private func persistSkills() {
        let snapshot = skills
        let repo = feedbackRepository
        scheduleSave(
            { try repo.saveSkills(snapshot) },
            failureTitle: "기술 목록을 저장하지 못했습니다"
        )
    }

    private func normalizedSkillName(_ name: String) -> String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
    }

    private func persistWarmupChecks() {
        guard let sessionId = selectedWarmupSessionId else { return }
        let dict = Dictionary(uniqueKeysWithValues: warmup.map { ($0.id, $0.checked) })
        warmupRepository.save(dict, sessionId: sessionId, for: .now)
    }

    private func persistWarmupSessions() {
        let snapshot = warmupSessions
        let repo = warmupRepository
        scheduleSave(
            { try repo.saveSessions(snapshot) },
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
        persistenceIssue = PersistenceIssue(
            title: title,
            message: "\(recovery)\n\n원인: \(error.localizedDescription)"
        )
    }

    private func moveItems<T>(_ items: inout [T], fromOffsets source: IndexSet, toOffset destination: Int) {
        let sortedSource = source.sorted()
        guard destination >= 0,
              destination <= items.count,
              sortedSource.allSatisfy({ items.indices.contains($0) }) else { return }

        let movingItems = sortedSource.map { items[$0] }

        for index in sortedSource.reversed() {
            items.remove(at: index)
        }

        let removedBeforeDestination = sortedSource.filter { $0 < destination }.count
        let insertionIndex = max(0, min(items.count, destination - removedBeforeDestination))
        items.insert(contentsOf: movingItems, at: insertionIndex)
    }
}
