#!/usr/bin/env python3
"""
Compare the greedy vs optimal team selection approaches
"""

import sys
from fm_team_selector import TeamSelector
from fm_team_selector_optimal import OptimalTeamSelector

def compare_selections(filepath: str):
    """
    Compare greedy and optimal selection methods
    
    Args:
        filepath: Path to player data file
    """
    formation = [
        ('GK', 'GK'),
        ('DL', 'D(R/L)'),
        ('DC1', 'D(C)'),
        ('DC2', 'D(C)'),
        ('DR', 'D(R/L)'),
        ('DM1', 'DM_avg'),
        ('DM2', 'DM_avg'),
        ('AML', 'AM(L)'),
        ('AMC', 'AM(C)'),
        ('AMR', 'AM(R)'),
        ('STC', 'Striker')
    ]
    
    print("\n" + "="*80)
    print("COMPARING GREEDY vs OPTIMAL SELECTION METHODS")
    print("="*80)
    
    # Greedy approach
    print("\n--- GREEDY APPROACH (Fast, but not always optimal) ---\n")
    greedy_selector = TeamSelector(filepath)
    greedy_selector.select_starting_xi(formation)
    greedy_ratings = [rating for _, rating in greedy_selector.starting_xi.values() if rating > 0]
    greedy_avg = sum(greedy_ratings) / len(greedy_ratings) if greedy_ratings else 0
    
    print("Selected Players:")
    for pos, (player, rating) in sorted(greedy_selector.starting_xi.items()):
        print(f"  {pos:6s}: {player:20s} ({rating:.1f})")
    print(f"\nAverage Rating: {greedy_avg:.2f}")
    
    # Optimal approach
    print("\n\n--- OPTIMAL APPROACH (Uses Hungarian algorithm) ---\n")
    optimal_selector = OptimalTeamSelector(filepath)
    optimal_selector.select_optimal_xi(formation)
    optimal_ratings = [rating for _, rating in optimal_selector.starting_xi.values() if rating > 0]
    optimal_avg = sum(optimal_ratings) / len(optimal_ratings) if optimal_ratings else 0
    
    print("Selected Players:")
    for pos, (player, rating) in sorted(optimal_selector.starting_xi.items()):
        print(f"  {pos:6s}: {player:20s} ({rating:.1f})")
    print(f"\nAverage Rating: {optimal_avg:.2f}")
    
    # Comparison
    print("\n" + "="*80)
    print("COMPARISON SUMMARY")
    print("="*80)
    print(f"Greedy Average:  {greedy_avg:.2f}")
    print(f"Optimal Average: {optimal_avg:.2f}")
    print(f"Improvement:     {optimal_avg - greedy_avg:+.2f} ({((optimal_avg - greedy_avg) / greedy_avg * 100):+.1f}%)")
    print("="*80 + "\n")
    
    # Show differences in selection
    greedy_players = set(player for player, _ in greedy_selector.starting_xi.values() if player)
    optimal_players = set(player for player, _ in optimal_selector.starting_xi.values() if player)
    
    only_greedy = greedy_players - optimal_players
    only_optimal = optimal_players - greedy_players
    
    if only_greedy or only_optimal:
        print("SELECTION DIFFERENCES:")
        print("-" * 80)
        if only_greedy:
            print(f"Players only in greedy selection: {', '.join(only_greedy)}")
        if only_optimal:
            print(f"Players only in optimal selection: {', '.join(only_optimal)}")
        print("-" * 80 + "\n")


if __name__ == "__main__":
    filepath = sys.argv[1] if len(sys.argv) > 1 else 'players.csv'
    
    try:
        compare_selections(filepath)
    except Exception as e:
        print(f"Error: {e}")
        import traceback
        traceback.print_exc()
        sys.exit(1)
