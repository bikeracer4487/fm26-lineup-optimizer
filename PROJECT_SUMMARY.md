# Football Manager Starting XI Selector - Project Summary

## What You're Getting

A complete Python-based solution for automatically selecting your optimal Starting XI in Football Manager based on your custom position ratings spreadsheet.

## Files Included

### Main Scripts (3 Python files)

1. **fm_team_selector_optimal.py** ⭐ RECOMMENDED
   - Uses Hungarian algorithm for truly optimal selection
   - Average rating: 88.55 (with sample data)
   - Best overall player-position assignments
   - Includes substitute suggestions

2. **fm_team_selector.py**
   - Greedy algorithm approach
   - Average rating: 86.73 (with sample data)
   - Faster but less optimal

3. **compare_selections.py**
   - Compare both approaches side-by-side
   - Shows improvement percentage
   - Highlights player differences

### Data & Configuration

4. **players.csv**
   - Sample data from your screenshot (35 players)
   - Use as template for your own data
   - Shows correct column format

5. **requirements.txt**
   - All Python dependencies listed
   - One command to install everything

### Documentation

6. **README.md**
   - Complete documentation
   - Usage instructions
   - Customization guide

7. **QUICKSTART.md**
   - Step-by-step getting started guide
   - Example outputs
   - Troubleshooting tips

## Key Features

### Automatic Optimal Selection
- Finds the best player for each position
- Maximizes total team rating
- Ensures no player is selected twice
- Considers all possible combinations

### Flexible Formation Support
- Default: 4-2-3-1 (GK, DL, DC, DC, DR, DM, DM, AML, AMC, AMR, STC)
- Easily customizable for any formation
- Examples included for 4-4-2, 3-5-2, etc.

### Smart Position Mapping
- DM positions: Uses average of DM(L) and DM(R)
- Full backs: Uses D(R/L) rating
- All positions map to your spreadsheet columns

### Rich Output
- Displays natural positions for each player
- Shows individual ratings
- Calculates average team rating
- Suggests substitute bench (7 players)
- Exports to CSV for tracking

## Why Two Versions?

### The Problem with Greedy Selection

The greedy approach processes positions in order:
1. Picks best GK (correct)
2. Picks best available DL (might be correct)
3. Picks best available DC (might not be optimal!)
...and so on.

**Problem:** Alan Hackney rates 92.5 as a striker but 85.5 as a full back. The greedy algorithm might pick him as a full back if it processes defense before attack, wasting his striker ability!

### The Solution: Hungarian Algorithm

The optimal approach considers ALL possible assignments simultaneously:
- Evaluates every possible player-position combination
- Finds the assignment that maximizes total team rating
- Guarantees the mathematically optimal solution

**Result:** +1.83 rating improvement (2.1% better) in the sample data

## Real-World Performance Comparison

Using your sample data:

| Approach | Avg Rating | Players "Out of Position" |
|----------|-----------|---------------------------|
| Greedy   | 86.73     | Connor Underhill as striker (78.1) 😞 |
| Optimal  | 88.55     | Alan Hackney as striker (92.5) 😊 |

The optimal version correctly identifies that:
- Alan Hackney (natural AM(C)) should play striker (92.5 rating)
- Not Connor Underhill (natural AM(C)) with only 78.1 striker rating

## How to Use

### Basic Usage
```bash
# Install dependencies
pip install -r requirements.txt

# Run optimal selector
python fm_team_selector_optimal.py players.csv
```

### With Your Own Data
1. Export your FM spreadsheet to CSV or Excel
2. Ensure columns match: Name, Striker, AM(L), AM(C), AM(R), DM(L), DM(R), D(C), D(R/L), GK
3. Run: `python fm_team_selector_optimal.py your_file.csv`

### Compare Methods
```bash
python compare_selections.py players.csv
```

## Customization Examples

### Different Formation (4-4-2)
Edit the `formation` list in the script:
```python
formation = [
    ('GK', 'GK'),
    ('DL', 'D(R/L)'),
    ('DC1', 'D(C)'),
    ('DC2', 'D(C)'),
    ('DR', 'D(R/L)'),
    ('ML', 'AM(L)'),
    ('MC1', 'DM_avg'),
    ('MC2', 'DM_avg'),
    ('MR', 'AM(R)'),
    ('STC1', 'Striker'),
    ('STC2', 'Striker')
]
```

### Use Specific DM Ratings
Instead of averaging DM(L) and DM(R):
```python
('DM1', 'DM(L)'),  # Use DM(L) rating for first DM
('DM2', 'DM(R)'),  # Use DM(R) rating for second DM
```

## Technical Details

### Algorithm: Hungarian Method
- Also known as Munkres assignment algorithm
- Time complexity: O(n³) where n is number of positions
- Solves the "assignment problem" optimally
- Used in scipy.optimize.linear_sum_assignment

### Why It Works
The algorithm finds the assignment that minimizes total cost (or maximizes total rating):
- Creates a cost matrix: players × positions
- Finds optimal matching using graph theory
- Guarantees no player assigned to multiple positions
- Guarantees maximum total team rating

## Limitations & Considerations

1. **Assumes ratings are accurate** - Quality of output depends on quality of input ratings
2. **No chemistry/morale** - Only considers position ratings, not player relationships
3. **No injuries/suspensions** - Assumes all players available
4. **Static optimization** - Doesn't consider future development or fatigue

## Future Enhancement Ideas

- [ ] Consider player age and potential for long-term planning
- [ ] Weight by fitness/condition for match-day selection
- [ ] Factor in player morale
- [ ] Support multiple tactics (A-team vs rotation team)
- [ ] Include player wages for budget optimization
- [ ] Suggest tactical adjustments based on opposition

## Support & Credits

Created for your Brixham AFC save in Football Manager 2026!

Based on your custom algorithm that averages in-possession and out-of-possession role ratings for each position.

Uses the Hungarian algorithm (developed in 1955 by Harold Kuhn) for optimal assignment.

---

**Bottom line:** Use `fm_team_selector_optimal.py` - it's worth the extra dependencies for the better results! 🎯
