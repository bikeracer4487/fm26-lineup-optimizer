/// Exact assignment of candidates to slots: fill as many slots as possible, then maximise total value.
///
/// Knows nothing about players or tactics. Implemented as the Hungarian algorithm (shortest augmenting
/// paths with row and column potentials, O(n^3)) on a square matrix padded with dummy rows or columns.
/// Deterministic: no randomness, no hashing, ties inside the algorithm are settled by strict `<` scans
/// in index order.
public enum AssignmentSolver {
    /// Tie-break weight. The perturbation is only a preference among equal solutions: its largest possible
    /// total is about 2.7e-5 (24 slots, 100 candidates), so it can outweigh a genuine difference smaller
    /// than that. `maximise` therefore also solves without it and keeps the unperturbed answer whenever
    /// that is better on the original values, so the result is never worse than the true optimum except
    /// by `floatNoise`. 1e-9 is large enough to stay visible against the 1e-10 spacing of doubles at the
    /// 1e6 costs below, and small enough not to alter any real preference.
    private static let tieBreakEpsilon = 1e-9

    /// Margin by which the unperturbed solution must beat the perturbed one on the original values before
    /// it is preferred; anything smaller is treated as float noise (sums of values up to 200 over 24 slots
    /// are accurate to about 1e-12).
    private static let floatNoise = 1e-9

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
        let perturbed = solve(values: values, epsilon: tieBreakEpsilon)
        let exact = solve(values: values, epsilon: 0)
        let a = score(values, perturbed)
        let b = score(values, exact)
        if b.filled > a.filled || (b.filled == a.filled && b.total > a.total + floatNoise) {
            return exact
        }
        return perturbed
    }

    private static func score(_ values: [[Double?]], _ result: [Int?]) -> (filled: Int, total: Double) {
        var filled = 0
        var total = 0.0
        for (s, choice) in result.enumerated() {
            if let p = choice, let v = values[s][p] { filled += 1; total += v }
        }
        return (filled, total)
    }

    private static func solve(values: [[Double?]], epsilon: Double) -> [Int?] {
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
                    let perturbation = epsilon * Double(col - 1) * Double(slots - (row - 1))
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
