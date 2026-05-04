import Foundation
import Observation

@Observable
final class AppStore {
    struct PersistenceIssue: Identifiable {
        let id = UUID()
        let title: String
        let message: String
    }

    private(set) var feedbacks: [Feedback] = []
    private(set) var skills: [Skill] = []
    private(set) var warmup: [WarmupItem] = []
    private(set) var quickPhrases: [String] = []
    private(set) var hasCompletedOnboarding = false
    private(set) var persistenceIssue: PersistenceIssue?

    private let feedbackRepository: FeedbackRepository
    private let warmupRepository: WarmupRepository
    private let settingsRepository: UserSettingsRepository
    private var currentWarmupDateKey = WarmupDateKey.today()
    private var needsInitialSkillSave = false

    init(
        feedbackRepository: FeedbackRepository = FeedbackRepository(),
        warmupRepository: WarmupRepository = WarmupRepository(),
        settingsRepository: UserSettingsRepository = UserSettingsRepository()
    ) {
        self.feedbackRepository = feedbackRepository
        self.warmupRepository = warmupRepository
        self.settingsRepository = settingsRepository
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

            if loadedSkills.isEmpty {
                loadedSkills = SampleData.defaultSkills()
                needsInitialSkillSave = true
            } else if DefaultSkillNormalizer.normalize(&loadedSkills) {
                try feedbackRepository.saveSkills(loadedSkills)
            }

            skills = loadedSkills
            feedbacks = loadedFeedbacks
            if !didCompleteOnboarding && !loadedFeedbacks.isEmpty {
                completeOnboarding()
            }
        } catch {
            skills = SampleData.defaultSkills()
            needsInitialSkillSave = true
            feedbacks = []
            reportPersistenceIssue(
                title: "데이터를 불러오지 못했습니다",
                error: error,
                recovery: "기본 기술 목록으로 시작합니다. 기존 기록 파일을 확인한 뒤 다시 시도해 주세요."
            )
        }

        warmup = loadWarmup(for: .now)
    }

    private func loadWarmup(for date: Date) -> [WarmupItem] {
        let routine: [WarmupItem]
        do {
            routine = try warmupRepository.loadRoutine() ?? DefaultWarmup.items
        } catch {
            routine = DefaultWarmup.items
            reportPersistenceIssue(
                title: "웜업 루틴을 불러오지 못했습니다",
                error: error,
                recovery: "기본 웜업 루틴으로 표시합니다."
            )
        }

        let saved = warmupRepository.load(for: date)
        return routine.map { base in
            var item = base
            item.checked = saved[base.id] ?? false
            return item
        }
    }

    // MARK: - Derived

    var activeFeedbacks: [Feedback] {
        FeedbackScoring.sortedActive(feedbacks)
    }

    var topFeedback: Feedback? { activeFeedbacks.first }

    func activeFeedbacks(forSkillId skillId: UUID) -> [Feedback] {
        FeedbackScoring.sortedActive(feedbacks.filter { $0.skillId == skillId })
    }

    func activeCount(forSkillId skillId: UUID) -> Int {
        feedbacks.filter { $0.skillId == skillId && $0.status == .active }.count
    }

    // MARK: - Feedback intents

    func addFeedback(skill: Skill, title: String, note: String, importance: Int) {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let new = Feedback(
            skillId: skill.id,
            skillName: skill.name,
            title: trimmed,
            note: note.trimmingCharacters(in: .whitespacesAndNewlines),
            importance: importance
        )
        feedbacks.append(new)
        persistInitialSkillsIfNeeded()
        persistFeedbacks()
    }

    func updateFeedback(_ updated: Feedback) {
        guard let idx = feedbacks.firstIndex(where: { $0.id == updated.id }) else { return }
        var copy = updated
        copy.updatedAt = .now
        feedbacks[idx] = copy
        persistFeedbacks()
    }

    func resolve(_ id: UUID) {
        guard let idx = feedbacks.firstIndex(where: { $0.id == id }) else { return }
        feedbacks[idx].status = .resolved
        feedbacks[idx].resolvedAt = .now
        feedbacks[idx].updatedAt = .now
        persistFeedbacks()
    }

    func markUnresolved(_ id: UUID) {
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

    func addSkill(name: String, symbolName: String = "ellipsis.circle") {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        skills.append(Skill(name: trimmed, symbolName: symbolName))
        persistSkills()
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

    func toggleWarmup(_ id: String) {
        guard let idx = warmup.firstIndex(where: { $0.id == id }) else { return }
        warmup[idx].checked.toggle()
        persistWarmup()
    }

    func resetWarmupToday() {
        warmup = warmup.map {
            WarmupItem(id: $0.id, label: $0.label)
        }
        warmupRepository.reset()
    }

    func addWarmupItem(label: String) {
        let trimmed = label.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        warmup.append(WarmupItem(id: "custom_\(UUID().uuidString)", label: trimmed))
        persistWarmupRoutine()
    }

    func updateWarmupItem(id: String, label: String) {
        let trimmed = label.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty,
              let idx = warmup.firstIndex(where: { $0.id == id }) else { return }
        warmup[idx].label = trimmed
        persistWarmupRoutine()
    }

    func deleteWarmupItem(_ id: String) {
        let beforeCount = warmup.count
        warmup.removeAll { $0.id == id }
        guard warmup.count != beforeCount else { return }
        persistWarmupRoutine()
        persistWarmup()
    }

    func moveWarmupItem(fromOffsets source: IndexSet, toOffset destination: Int) {
        guard !source.isEmpty else { return }
        moveItems(&warmup, fromOffsets: source, toOffset: destination)
        persistWarmupRoutine()
        persistWarmup()
    }

    func resetWarmupRoutine() {
        warmup = DefaultWarmup.items
        warmupRepository.resetRoutine()
        warmupRepository.reset()
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
        settingsRepository.saveQuickPhrases(phrases)
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
        do {
            try feedbackRepository.saveFeedbacks(feedbacks)
        } catch {
            reportPersistenceIssue(
                title: "피드백을 저장하지 못했습니다",
                error: error,
                recovery: "앱을 종료하기 전에 저장 공간과 파일 권한을 확인해 주세요."
            )
        }
    }

    private func persistSkills() {
        do {
            try feedbackRepository.saveSkills(skills)
            needsInitialSkillSave = false
        } catch {
            reportPersistenceIssue(
                title: "기술 목록을 저장하지 못했습니다",
                error: error,
                recovery: "앱을 종료하기 전에 저장 공간과 파일 권한을 확인해 주세요."
            )
        }
    }

    private func persistInitialSkillsIfNeeded() {
        guard needsInitialSkillSave else { return }
        persistSkills()
    }

    private func persistWarmup() {
        let dict = Dictionary(uniqueKeysWithValues: warmup.map { ($0.id, $0.checked) })
        warmupRepository.save(dict)
    }

    private func persistWarmupRoutine() {
        do {
            try warmupRepository.saveRoutine(warmup)
        } catch {
            reportPersistenceIssue(
                title: "웜업 루틴을 저장하지 못했습니다",
                error: error,
                recovery: "앱을 종료하기 전에 저장 공간과 파일 권한을 확인해 주세요."
            )
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
