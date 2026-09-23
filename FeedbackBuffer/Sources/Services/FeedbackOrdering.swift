import Foundation

/// 버퍼의 순서를 다루는 순수 로직.
///
/// 순서는 계산하지 않는다. 저장된 배열 순서가 곧 화면 순서이고,
/// 사용자의 행동(새로 적기, 또 하기, 끌어서 옮기기)만이 그 순서를 바꾼다.
enum FeedbackOrdering {

    // MARK: - 이관

    /// 점수제에서 넘어올 때 한 번 쓴다. 마지막으로 손댄 순(최근 것이 앞)으로 세운다.
    ///
    /// 옛 배열은 추가된 순서라 오래된 것이 앞이다. 그대로 쓰면 목록이 거꾸로 선다.
    /// 같은 시각이면 원래 순서를 지킨다.
    static func migratedOrder(_ feedbacks: [Feedback]) -> [Feedback] {
        feedbacks.enumerated()
            .sorted { lhs, rhs in
                if lhs.element.referenceDate != rhs.element.referenceDate {
                    return lhs.element.referenceDate > rhs.element.referenceDate
                }
                return lhs.offset < rhs.offset
            }
            .map(\.element)
    }

    // MARK: - 맨 앞으로

    /// 새로 적거나 "또 하기"를 누른 항목을 맨 앞으로 보낸다.
    static func movingToFront(_ id: UUID, in feedbacks: [Feedback]) -> [Feedback] {
        guard let index = feedbacks.firstIndex(where: { $0.id == id }), index > 0 else { return feedbacks }
        var result = feedbacks
        let item = result.remove(at: index)
        result.insert(item, at: 0)
        return result
    }

    // MARK: - 끌어서 옮기기

    /// 화면에 보이는 일부(`visibleIds`) 안에서 옮긴 결과를 전체 배열에 반영한다.
    ///
    /// 보이는 항목들이 차지하던 **자리는 그대로 두고**, 그 자리에 새 순서로 다시 채운다.
    /// 보관한 것이나 다른 구역(오늘 할 것)에 있는 항목은 한 칸도 움직이지 않는다.
    static func reordering(
        _ feedbacks: [Feedback],
        visibleIds: [UUID],
        fromOffsets source: IndexSet,
        toOffset destination: Int
    ) -> [Feedback] {
        var moved = visibleIds
        moveItems(&moved, fromOffsets: source, toOffset: destination)
        guard moved != visibleIds else { return feedbacks }

        let visible = Set(visibleIds)
        let byId = Dictionary(uniqueKeysWithValues: feedbacks.map { ($0.id, $0) })
        var queue = moved.compactMap { byId[$0] }[...]

        return feedbacks.map { feedback in
            guard visible.contains(feedback.id), let next = queue.popFirst() else { return feedback }
            return next
        }
    }

    // MARK: - 임시 순서

    /// 필터 중에 끌어서 만든 임시 순서를 적용한다. 저장된 순서는 건드리지 않는다.
    ///
    /// - 임시 순서에 없는 항목(방금 새로 적은 것)은 맨 위에, 저장된 순서대로 붙는다
    /// - 임시 순서에는 있는데 지금 없는 항목(해결·삭제한 것)은 자연히 빠진다
    static func applyingTemporaryOrder(_ feedbacks: [Feedback], order: [UUID]) -> [Feedback] {
        guard !order.isEmpty else { return feedbacks }
        let rank = Dictionary(order.enumerated().map { ($1, $0) }, uniquingKeysWith: { first, _ in first })
        let unranked = feedbacks.filter { rank[$0.id] == nil }
        let ranked = feedbacks
            .filter { rank[$0.id] != nil }
            .sorted { rank[$0.id]! < rank[$1.id]! }
        return unranked + ranked
    }
}
