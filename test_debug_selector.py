#!/usr/bin/env python3
"""
Quick test script to debug DC2 and DM(R) assignment issues.
"""

from fm_match_ready_selector import MatchReadySelector

# Load the selector
selector = MatchReadySelector('players-current.csv', 'players.csv')

# Run with debug mode for a single match
print("\n" + "=" * 100)
print("DEBUG TEST - Single Match Selection")
print("=" * 100)

# Identify players to rest (same logic as the main script)
rested_players = selector._identify_players_to_rest()

print(f"\nPlayers being rested: {len(rested_players)}")
for player in rested_players:
    print(f"  - {player}")

# Select XI with debug enabled
selection = selector.select_match_xi(
    match_importance='Medium',
    prioritize_sharpness=False,
    rested_players=rested_players,
    debug=True
)

print("\n" + "=" * 100)
print("FINAL SELECTION:")
print("=" * 100)

for pos in ['GK', 'DL', 'DC1', 'DC2', 'DR', 'DM(L)', 'DM(R)', 'AML', 'AMC', 'AMR', 'STC']:
    if pos in selection:
        player_name, eff_rating, _ = selection[pos]
        print(f"  {pos:6}: {player_name:25} (Eff: {eff_rating:5.1f})")
    else:
        print(f"  {pos:6}: NO PLAYER FOUND")
