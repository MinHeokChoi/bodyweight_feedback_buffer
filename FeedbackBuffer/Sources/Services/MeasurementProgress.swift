import Foundation

/// 측정 기록을 시즌 단위로 접어서 비교 가능한 모습으로 만드는 순수 로직.
///
/// 이 기능의 존재 이유는 시즌 간 비교다. 그래서 여기서 중요한 것은 두 가지다 —
/// 방향(클수록 좋은가, 작을수록 좋은가)과 제약이 그대로였는가.
enum MeasurementProgress {

    /// 한 시즌에서 한 종목의 결과.
    struct SeasonEntry: Identifiable, Hashable {
        let season: MeasurementSeason
        /// 방향을 적용한 그 시즌의 대표값. 여러 번 쟀다면 가장 잘한 값이다.
        let best: Double
        /// 그 시즌의 기록 전부. 최신 순.
        let records: [MeasurementRecord]
        /// 직전 시즌 대비 변화. 방향을 적용했으므로 양수면 개선이다. 첫 시즌이면 nil.
        let improvement: Double?
        /// 이 시즌의 기록 중 지금 종목 제약과 다른 조건에서 잰 것이 있는가.
        let constraintChanged: Bool

        var id: UUID { season.id }

        var isImproved: Bool { (improvement ?? 0) > 0 }
        var isRegressed: Bool { (improvement ?? 0) < 0 }
    }

    /// 한 종목의 시즌별 이력. 최신 시즌이 앞이다.
    static func history(
        of item: MeasurementItem,
        records: [MeasurementRecord],
        seasons: [MeasurementSeason]
    ) -> [SeasonEntry] {
        let mine = records.filter { $0.itemId == item.id }
        guard !mine.isEmpty else { return [] }

        let seasonById = Dictionary(uniqueKeysWithValues: seasons.map { ($0.id, $0) })
        let grouped = Dictionary(grouping: mine) { $0.seasonId }

        // 오래된 시즌부터 훑어야 "직전 시즌 대비"를 계산할 수 있다.
        let ordered = grouped.compactMap { seasonId, values -> (MeasurementSeason, [MeasurementRecord])? in
            guard let season = seasonById[seasonId] else { return nil }
            return (season, values.sorted { $0.measuredAt > $1.measuredAt })
        }
        .sorted { $0.0.startedAt < $1.0.startedAt }

        var entries: [SeasonEntry] = []
        var previousBest: Double?

        for (season, values) in ordered {
            // 마지막 값이 가장 잘한 값이라는 보장이 없다. 방향을 적용해 고른다.
            let best = values.map(\.value).reduce(values[0].value) { item.direction.better($0, $1) }
            let changed = values.contains {
                !$0.constraintSnapshot.isEmpty && $0.constraintSnapshot != item.constraint
            }

            entries.append(
                SeasonEntry(
                    season: season,
                    best: best,
                    records: values,
                    improvement: previousBest.map { item.direction.improvement(from: $0, to: best) },
                    constraintChanged: changed
                )
            )
            previousBest = best
        }

        return entries.reversed()
    }

    /// 한 시즌에서 잰 모든 종목의 대표값. 시즌 상세 화면에서 쓴다.
    static func summary(
        of season: MeasurementSeason,
        items: [MeasurementItem],
        records: [MeasurementRecord],
        seasons: [MeasurementSeason]
    ) -> [(item: MeasurementItem, entry: SeasonEntry)] {
        items.compactMap { item in
            guard let entry = history(of: item, records: records, seasons: seasons)
                .first(where: { $0.season.id == season.id }) else { return nil }
            return (item, entry)
        }
    }

    /// 지금 진행 중인 시즌. 시작일이 가장 늦은 시즌이다.
    static func current(in seasons: [MeasurementSeason]) -> MeasurementSeason? {
        seasons.max { $0.startedAt < $1.startedAt }
    }
}
