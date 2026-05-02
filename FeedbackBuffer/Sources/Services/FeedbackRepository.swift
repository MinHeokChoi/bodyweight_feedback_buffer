import Foundation

final class FeedbackRepository {
    private let store: FileStore
    private let feedbacksFile = "feedbacks.json"
    private let skillsFile = "skills.json"

    init(store: FileStore = JSONStore()) {
        self.store = store
    }

    func loadFeedbacks() throws -> [Feedback] {
        try store.load([Feedback].self, from: feedbacksFile) ?? []
    }

    func saveFeedbacks(_ feedbacks: [Feedback]) throws {
        try store.save(feedbacks, to: feedbacksFile)
    }

    func loadSkills() throws -> [Skill] {
        try store.load([Skill].self, from: skillsFile) ?? []
    }

    func saveSkills(_ skills: [Skill]) throws {
        try store.save(skills, to: skillsFile)
    }
}
