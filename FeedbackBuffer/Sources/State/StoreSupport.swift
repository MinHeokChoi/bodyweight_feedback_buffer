import Foundation

struct PersistenceScheduler {
    let perform: (@escaping () -> Void) -> Void

    static let background: PersistenceScheduler = {
        let queue = DispatchQueue(label: "com.feedbackbuffer.persistence", qos: .utility)
        return PersistenceScheduler { queue.async(execute: $0) }
    }()

    static let immediate = PersistenceScheduler { $0() }
}

struct PersistenceIssue: Identifiable {
    let id = UUID()
    let title: String
    let message: String
}

func moveItems<T>(_ items: inout [T], fromOffsets source: IndexSet, toOffset destination: Int) {
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
