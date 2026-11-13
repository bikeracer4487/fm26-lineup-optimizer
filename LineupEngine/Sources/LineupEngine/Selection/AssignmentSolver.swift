/// Exact assignment of candidates to slots: fill as many slots as possible, then maximise total value.
///
/// Knows nothing about players or tactics. Implemented as the Hungarian algorithm (shortest augmenting
/// paths with row and column potentials, O(n^3)) on a square matrix padded with dummy rows or columns.
/// Deterministic: no randomness, no hashing, ties inside the algorithm are settled by strict `<` scans
/// in index order.
public enum AssignmentSolver {
    /// Tie-break weight. A solution's perturbation is at most 1e-9 x 100 candidates x 24 slots x 24 slots
    /// (about 6e-5 even with every index at its maximum), far below any gap between genuinely different
    /// totals in this engine (values are 0 to 200 and differ by whole rating points or fractions well
    /// above 1e-4), so it can only choose among solutions whose original totals are equal. It is also large
    /// enough to stay distinguishable from rounding noise on values near 200 (double spacing there is ~3e-14).
    private static let tieBreakEpsilon = 1e-9

    /// Cost of a disallowed pairing or of a dummy candidate. Must exceed the largest total value swing
    /// that filling one extra slot could ever buy back: with at most about 24 slots at values 0...200 that
    /// swing is under 24 x 200 = 4,800, so 1e6 (over 200 times larger) always makes "fill one more slot"
    /// win over any gain in total value. It is kept this small, not larger, so that sums of costs
    /// (up to ~2.4e7 for 24 dummies) stay well within double precision and the 1e-9 tie-break survives.
    private static let unfillableCost = 1e6

    /// - Parameter values: `values[s][p]` is candidate `p` in slot `s`; nil means not allowed.
    ///   Precondition: rectangular (every row has the same length).
    /// - Returns: one entry per slot, the chosen candidate index or nil if the slot cannot be filled.
    ///   Each candidate is used at most once.
    public static func maximise(values: [[Double?]]) -> [Int?] {
        let slots = values.count
        guard slots > 0 else { return [] }
        let candidates = values[0].count
        guard candidates > 0 else { return Array(repeating: nil, count: slots) }

        // Square cost matrix, 1-based for the classic formulation. Rows 1...slots are slots, further rows
        // are dummy slots (cost 0: taking one costs nothing). Columns 1...candidates are candidates,
        // further columns are dummy candidates (cost `unfillableCost`).
        let n = max(slots, candidates)
        var cost = [[Double]](repeating: [Double](repeating: 0, count: n + 1), count: n + 1)
        for row in 1...n {
            for col in 1...n {
                if row > slots {
                    cost[row][col] = 0
                } else if col > candidates {
                    cost[row][col] = unfillableCost
                } else if let value = values[row - 1][col - 1] {
                    let perturbation = tieBreakEpsilon * Double(col - 1) * Double(slots - (row - 1))
                    cost[row][col] = -(value - perturbation)
                } else {
                    cost[row][col] = unfillableCost
                }
            }
        }

        var rowPotential = [Double](repeating: 0, count: n + 1)
        var colPotential = [Double](repeating: 0, count: n + 1)
        var matchedRow = [Int](repeating: 0, count: n + 1)   // matchedRow[col] = row, 0 if free
        var way = [Int](repeating: 0, count: n + 1)

        for row in 1...n {
            matchedRow[0] = row
            var col0 = 0
            var minSlack = [Double](repeating: .infinity, count: n + 1)
            var used = [Bool](repeating: false, count: n + 1)
            repeat {
                used[col0] = true
                let row0 = matchedRow[col0]
                var delta = Double.infinity
                var col1 = 0
                for col in 1...n where !used[col] {
                    let slack = cost[row0][col] - rowPotential[row0] - colPotential[col]
                    if slack < minSlack[col] { minSlack[col] = slack; way[col] = col0 }
                    if minSlack[col] < delta { delta = minSlack[col]; col1 = col }
                }
                for col in 0...n {
                    if used[col] {
                        rowPotential[matchedRow[col]] += delta
                        colPotential[col] -= delta
                    } else {
                        minSlack[col] -= delta
                    }
                }
                col0 = col1
            } while matchedRow[col0] != 0
            repeat {
                let col1 = way[col0]
                matchedRow[col0] = matchedRow[col1]
                col0 = col1
            } while col0 != 0
        }

        var result = [Int?](repeating: nil, count: slots)
        for col in 1...candidates {
            let row = matchedRow[col]
            if row >= 1, row <= slots, values[row - 1][col - 1] != nil {
                result[row - 1] = col - 1
            }
        }
        return result
    }
}
