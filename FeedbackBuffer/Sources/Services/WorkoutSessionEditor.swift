import Foundation

/// 기록을 "길이"만으로 다시 짜는 순수 로직.
///
/// 이 기록의 목적은 구간별 누적 시간이다. 휴식은 구간 사이에 남는 시간일 뿐
/// 기록 대상이 아니다. 그래서 편집은 시각을 다루지 않고 길이만 다룬다.
/// 길이가 바뀌면 그 뒤의 구간이 통째로 밀리고, 구간 사이 간격은 그대로 유지된다.
enum WorkoutSessionEditor {

    /// 수동 기록은 하루 중 언제였는지를 묻지 않는다. 정렬과 표시를 위한 자리만 필요해서
    /// 그날 정오에 둔다. 화면에서는 시각 대신 "직접 입력"을 보여준다.
    static let manualSessionHour = 12

    /// 편집 화면이 다루는 단위. 종류와 길이가 전부다.
    struct Block: Identifiable, Hashable {
        let id: UUID
        var kind: TrainingPhaseKind
        var duration: TimeInterval

        init(id: UUID = UUID(), kind: TrainingPhaseKind, duration: TimeInterval) {
            self.id = id
            self.kind = kind
            self.duration = max(0, duration)
        }
    }

    // MARK: - 읽기

    /// 저장된 기록을 편집 단위로 펼친다. 시작 시각 순서를 따른다.
    static func blocks(of session: WorkoutSession) -> [Block] {
        orderedSegments(of: session).map { segment in
            Block(
                id: segment.id,
                kind: segment.kind,
                duration: duration(of: segment, in: session)
            )
        }
    }

    // MARK: - 만들기

    /// 수동 기록을 만든다. 구간을 순서대로 이어 붙이므로 휴식은 0이다.
    /// 사후 입력에는 "구간 사이의 간격"이라는 사실 자체가 없어서 지어내지 않는다.
    ///
    /// 길이가 1초 미만인 블록은 버린다. 남는 블록이 없으면 nil을 준다.
    static func makeManualSession(
        date: Date,
        blocks: [Block],
        calendar: Calendar = .current
    ) -> WorkoutSession? {
        let usable = blocks.filter { $0.duration >= 1 }
        guard !usable.isEmpty else { return nil }

        let start = calendar.date(
            bySettingHour: manualSessionHour,
            minute: 0,
            second: 0,
            of: date
        ) ?? calendar.startOfDay(for: date)

        var cursor = start
        var segments: [TrainingSegment] = []
        for block in usable {
            let end = cursor.addingTimeInterval(block.duration)
            segments.append(
                TrainingSegment(
                    kind: block.kind,
                    startedAt: cursor,
                    endedAt: end,
                    laps: derivedLaps(kind: block.kind, duration: block.duration)
                )
            )
            cursor = end
        }

        return WorkoutSession(
            startedAt: start,
            endedAt: cursor,
            segments: segments,
            pauses: [],
            source: .manual
        )
    }

    // MARK: - 고치기

    /// 기존 기록에 새 길이를 적용한다.
    ///
    /// - 구간 사이 간격(= 휴식)은 그 구간을 따라 유지된다. 새로 추가된 구간의 간격은 0이다.
    /// - 길이나 종류가 바뀐 구간은 랩을 새 길이에서 다시 계산한다.
    ///   저장돼 있던 랩은 옛 길이의 산물이라 그대로 두면 합이 맞지 않는다.
    /// - **일시정지 기록은 사라진다.** 남겨두면 화면에 보이는 길이가 입력한 길이와
    ///   달라진다. 손으로 총량을 고친 뒤에 일시정지를 붙들고 있을 이유가 없다.
    static func apply(_ blocks: [Block], to session: WorkoutSession) -> WorkoutSession? {
        let usable = blocks.filter { $0.duration >= 1 }
        guard !usable.isEmpty else { return nil }

        let original = orderedSegments(of: session)
        let originalById = Dictionary(uniqueKeysWithValues: original.map { ($0.id, $0) })
        let gaps = gapsBefore(original)
        let lead = original.first.map { max(0, $0.startedAt.timeIntervalSince(session.startedAt)) } ?? 0
        let tail = tailGap(of: session, orderedSegments: original)

        var cursor = session.startedAt.addingTimeInterval(lead)
        var segments: [TrainingSegment] = []

        for (offset, block) in usable.enumerated() {
            if offset > 0 {
                cursor = cursor.addingTimeInterval(gaps[block.id] ?? 0)
            }
            let end = cursor.addingTimeInterval(block.duration)
            let previous = originalById[block.id]
            let unchanged = previous.map {
                $0.kind == block.kind
                    && abs(duration(of: $0, in: session) - block.duration) < 1
            } ?? false

            segments.append(
                TrainingSegment(
                    id: block.id,
                    kind: block.kind,
                    skillId: previous?.skillId,
                    startedAt: cursor,
                    endedAt: end,
                    // 손대지 않은 구간의 랩은 그대로 둔다. 그날 실제로 그렇게 나뉜 기록이다.
                    laps: unchanged
                        ? (previous?.laps ?? [])
                        : derivedLaps(kind: block.kind, duration: block.duration)
                )
            )
            cursor = end
        }

        var updated = session
        updated.segments = segments
        updated.pauses = []
        updated.endedAt = cursor.addingTimeInterval(tail)
        return updated
    }

    // MARK: - 랩

    /// 길이에서 랩을 유도한다. 9분마다 한 운동이고, 남는 시간은 마지막 랩이 된다.
    static func derivedLaps(
        kind: TrainingPhaseKind,
        duration: TimeInterval,
        target: TimeInterval = PaceTimer.defaultLapDuration
    ) -> [TrainingLap] {
        guard kind.usesPaceTimer, duration >= 1, target >= 1 else { return [] }

        var laps: [TrainingLap] = []
        var remaining = duration
        var index = 1
        while remaining >= target {
            laps.append(TrainingLap(index: index, duration: target, targetDuration: target))
            remaining -= target
            index += 1
        }
        if remaining >= 1 {
            laps.append(TrainingLap(index: index, duration: remaining, targetDuration: target))
        }
        return laps
    }

    // MARK: - 조각

    /// 끝난 구간의 길이. 끝나지 않았다면 세션 종료 시각까지로 본다.
    private static func duration(of segment: TrainingSegment, in session: WorkoutSession) -> TimeInterval {
        let end = segment.endedAt ?? session.endedAt ?? segment.startedAt
        return WorkoutClock.duration(of: segment, pauses: session.pauses, now: end)
    }

    private static func orderedSegments(of session: WorkoutSession) -> [TrainingSegment] {
        session.segments.sorted { $0.startedAt < $1.startedAt }
    }

    /// 각 구간 앞에 있던 빈 시간. 첫 구간은 세션 시작과의 간격을 따로 다루므로 빠진다.
    private static func gapsBefore(_ segments: [TrainingSegment]) -> [UUID: TimeInterval] {
        var gaps: [UUID: TimeInterval] = [:]
        for index in segments.indices.dropFirst() {
            guard let previousEnd = segments[index - 1].endedAt else { continue }
            gaps[segments[index].id] = max(0, segments[index].startedAt.timeIntervalSince(previousEnd))
        }
        return gaps
    }

    private static func tailGap(
        of session: WorkoutSession,
        orderedSegments: [TrainingSegment]
    ) -> TimeInterval {
        guard let end = session.endedAt,
              let lastEnd = orderedSegments.last?.endedAt else { return 0 }
        return max(0, end.timeIntervalSince(lastEnd))
    }
}
