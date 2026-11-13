import Testing
@testable import LineupEngine

/// Seeded linear congruential generator so the random problems are repeatable.
private struct LCG {
    var state: UInt64
    mutating func next() -> UInt64 {
        state = state &* 6364136223846793005 &+ 1442695040888963407
        return state >> 33
    }
    mutating func below(_ n: Int) -> Int { Int(next() % UInt64(n)) }
    mutating func unit() -> Double { Double(next() % 1_000_000) / 1_000_000 }
}

/// Exhaustive search: most slots filled, then highest total of the original values.
private func bruteForce(_ values: [[Double?]]) -> (filled: Int, total: Double) {
    let slots = values.count
    let candidates = values.first?.count ?? 0
    var best: (filled: Int, total: Double) = (0, 0)
    func go(_ s: Int, _ used: Set<Int>, _ filled: Int, _ total: Double) {
        if s == slots {
            if filled > best.filled || (filled == best.filled && total > best.total) {
                best = (filled, total)
            }
            return
        }
        go(s + 1, used, filled, total)
        for p in 0..<candidates where !used.contains(p) {
            if let v = values[s][p] { go(s + 1, used.union([p]), filled + 1, total + v) }
        }
    }
    go(0, [], 0, 0)
    return best
}

private func score(_ values: [[Double?]], _ result: [Int?]) -> (filled: Int, total: Double) {
    var filled = 0
    var total = 0.0
    for (s, choice) in result.enumerated() {
        if let p = choice, let v = values[s][p] { filled += 1; total += v }
    }
    return (filled, total)
}

@Suite struct AssignmentSolverTests {
    @Test func picksTheGloballyBestNotTheGreedyBest() {
        // slot 0: [10, 9], slot 1: [9, 1] -> greedy gives 10 + 1; optimum is 9 + 9
        #expect(AssignmentSolver.maximise(values: [[10, 9], [9, 1]]) == [1, 0])
    }

    @Test func identicalColumnsBreakTiesByCandidateOrder() {
        #expect(AssignmentSolver.maximise(values: [[5, 5, 5], [5, 5, 5]]) == [0, 1])
    }

    @Test func aSlotNobodyCanPlayIsNil() {
        #expect(AssignmentSolver.maximise(values: [[nil, nil], [3, 4]]) == [nil, 1])
    }

    @Test func fillingMoreSlotsBeatsAHigherTotal() {
        // candidate 0 is the only one allowed in slot 1; putting him in slot 0 scores more but leaves slot 1 empty
        #expect(AssignmentSolver.maximise(values: [[100, 1], [50, nil]]) == [1, 0])
    }

    @Test func moreSlotsThanCandidatesLeavesTheWorstSlotEmpty() {
        #expect(AssignmentSolver.maximise(values: [[9], [5]]) == [0, nil])
    }

    @Test func emptyInputsGiveEmptyOrAllNilResults() {
        #expect(AssignmentSolver.maximise(values: []) == [])
        #expect(AssignmentSolver.maximise(values: [[], []]) == [nil, nil])
    }

    @Test func matchesBruteForceOnTwoHundredRandomProblems() {
        var rng = LCG(state: 2027)
        for i in 0..<200 {
            let slots = 1 + rng.below(5)
            let candidates = 1 + rng.below(7)
            let tied = i % 2 == 0   // every other problem draws from a few integers so ties are common
            let tiny = i % 5 == 1   // some problems differ only by amounts far below 1e-6
            let values: [[Double?]] = (0..<slots).map { _ in
                (0..<candidates).map { _ in
                    if rng.unit() < 0.15 { return nil }
                    if tiny { return 100 + Double(rng.below(5)) * 1e-8 }
                    return tied ? Double(rng.below(4)) * 10 : rng.unit() * 200
                }
            }
            let result = AssignmentSolver.maximise(values: values)
            #expect(result.count == slots)
            let chosen = result.compactMap { $0 }
            #expect(Set(chosen).count == chosen.count, "candidate reused in problem \(i)")
            for (s, p) in result.enumerated() { if let p { #expect(values[s][p] != nil) } }
            let got = score(values, result)
            let want = bruteForce(values)
            #expect(got.filled == want.filled, "filled slots differ in problem \(i)")
            #expect(abs(got.total - want.total) < (tiny ? 1e-9 : 1e-6), "total differs in problem \(i)")
            #expect(AssignmentSolver.maximise(values: values) == result)
        }
    }

    /// Two slots, candidates 0 and 99 far apart so the tie-break perturbation differs between the two options.
    private func farApartProblem(gain: Double) -> [[Double?]] {
        var row0 = [Double?](repeating: nil, count: 100)
        var row1 = [Double?](repeating: nil, count: 100)
        row0[99] = 100 + gain   // option A: slot 0 -> 99, slot 1 -> 0
        row1[0] = 100
        row0[0] = 100           // option B: slot 0 -> 0, slot 1 -> 99
        row1[99] = 100
        return [row0, row1]
    }

    @Test func aTrueOptimumBeatsTheTieBreakEvenWhenTheMarginIsTiny() {
        // A beats B by 5e-8, less than the perturbation gap (~9.9e-8) that favours B
        #expect(AssignmentSolver.maximise(values: farApartProblem(gain: 5e-8)) == [99, 0])
    }

    @Test func exactlyEqualTotalsStillGoToTheLowerCandidateInTheEarlierSlot() {
        #expect(AssignmentSolver.maximise(values: farApartProblem(gain: 0)) == [0, 99])
    }

    @Test func permutingCandidatesPermutesTheAnswer() {
        // unique optimum: distinct values everywhere
        let values: [[Double?]] = [
            [71, 64, 88, 52, 90],
            [60, 93, 59, 75, 66],
            [81, 55, 70, 62, 77],
        ]
        let base = AssignmentSolver.maximise(values: values)
        let order = [3, 0, 4, 1, 2]   // new column k holds old column order[k]
        let permuted = values.map { row in order.map { row[$0] } }
        let result = AssignmentSolver.maximise(values: permuted)
        #expect(result.map { $0.map { order[$0] } } == base)
    }

    @Test func elevenSlotsSixtyCandidatesSolvesQuickly() {
        var rng = LCG(state: 11)
        let values: [[Double?]] = (0..<11).map { _ in (0..<60).map { _ in rng.unit() * 200 } }
        let result = AssignmentSolver.maximise(values: values)
        let chosen = result.compactMap { $0 }
        #expect(chosen.count == 11)
        #expect(Set(chosen).count == 11)
    }

    @Test func engineSizedProblemWithManyDisallowedPairingsStillFillsAsManySlotsAsPossible() {
        // 24 slots x 100 candidates, values 0...200, a third of pairings disallowed
        var rng = LCG(state: 24)
        let values: [[Double?]] = (0..<24).map { _ in
            (0..<100).map { _ in rng.unit() < 0.33 ? nil : (rng.below(2) == 0 ? 200 : rng.unit() * 200) }
        }
        let result = AssignmentSolver.maximise(values: values)
        #expect(result.compactMap { $0 }.count == 24)
        #expect(AssignmentSolver.maximise(values: values) == result)
    }
}
