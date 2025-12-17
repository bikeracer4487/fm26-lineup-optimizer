import { useState, useEffect, useCallback } from 'react';
import type { AppState, Match, TacticConfig } from '../types';
import { api } from '../api';

const DEFAULT_STATE: AppState = {
  currentDate: new Date().toISOString().split('T')[0],
  matches: [],
  rejectedPlayers: {},
  rejectedTraining: {},
  files: {
    status: 'players-current.csv',
    abilities: 'players-current.csv'
  },
  tacticConfig: {
    ipPositions: {},
    oopPositions: {},
    mapping: {}
  }
};

export function useAppState() {
  const [state, setState] = useState<AppState>(DEFAULT_STATE);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    const load = async () => {
      try {
        const loaded = await api.getAppState();
        if (loaded) {
          // Merge with default state to ensure new fields (like tacticConfig) exist if loading old state
          setState({ ...DEFAULT_STATE, ...loaded });
        }
      } catch (e) {
        console.error("Failed to load app state", e);
        setError(String(e));
      } finally {
        setLoading(false);
      }
    };
    load();
  }, []);

  const save = useCallback(async (newState: AppState) => {
    setState(newState);
    try {
      await api.saveAppState(newState);
    } catch (e) {
      console.error("Failed to save state", e);
    }
  }, []);

  const updateDate = (date: string) => {
    save({ ...state, currentDate: date });
  };

  const updateMatches = (matches: Match[]) => {
    // Rejections are now keyed by matchId (UUID), no index remapping needed
    // Just filter out rejections for matches that no longer exist
    const validMatchIds = new Set(matches.map(m => m.id));
    const filteredRejections: Record<string, string[]> = {};
    Object.entries(state.rejectedPlayers).forEach(([matchId, players]) => {
      if (validMatchIds.has(matchId) && players.length > 0) {
        filteredRejections[matchId] = players;
      }
    });

    save({ ...state, matches, rejectedPlayers: filteredRejections });
  };

  const updateRejectedPlayers = (matchId: string, players: string[]) => {
    save({
      ...state,
      rejectedPlayers: {
        ...state.rejectedPlayers,
        [matchId]: players
      }
    });
  };
  
  const resetRejectedPlayers = () => {
      save({ ...state, rejectedPlayers: {} });
  };

  const updateRejectedTraining = (player: string, position: string) => {
    save({
      ...state,
      rejectedTraining: {
        ...state.rejectedTraining,
        [player]: position
      }
    });
  };

  const resetRejectedTraining = () => {
      save({ ...state, rejectedTraining: {} });
  };

  const updateFiles = (files: { status: string, abilities: string }) => {
    save({ ...state, files });
  };

  const updateTacticConfig = (config: TacticConfig) => {
    save({ ...state, tacticConfig: config });
  };

  // Confirm a match lineup (locks it from recalculation)
  const confirmMatch = (matchId: string) => {
    const updatedMatches = state.matches.map(m => {
      if (m.id === matchId) {
        return {
          ...m,
          confirmed: true,
          confirmedAt: new Date().toISOString()
        };
      }
      return m;
    });
    save({ ...state, matches: updatedMatches });
  };

  // Undo confirmation (allows recalculation again)
  const undoConfirmation = (matchId: string) => {
    const updatedMatches = state.matches.map(m => {
      if (m.id === matchId) {
        return {
          ...m,
          confirmed: false,
          confirmedAt: undefined
        };
      }
      return m;
    });
    save({ ...state, matches: updatedMatches });
  };

  // Update manual overrides for a specific match
  const updateManualOverrides = (matchId: string, overrides: Record<string, string>) => {
    const updatedMatches = state.matches.map(m => {
      if (m.id === matchId) {
        return {
          ...m,
          manualOverrides: overrides
        };
      }
      return m;
    });
    save({ ...state, matches: updatedMatches });
  };

  // Clear all manual overrides for a specific match
  const clearManualOverrides = (matchId: string) => {
    const updatedMatches = state.matches.map(m => {
      if (m.id === matchId) {
        return {
          ...m,
          manualOverrides: undefined
        };
      }
      return m;
    });
    save({ ...state, matches: updatedMatches });
  };

  return {
    state,
    loading,
    error,
    updateDate,
    updateMatches,
    updateRejectedPlayers,
    resetRejectedPlayers,
    updateRejectedTraining,
    resetRejectedTraining,
    updateFiles,
    updateTacticConfig,
    confirmMatch,
    undoConfirmation,
    updateManualOverrides,
    clearManualOverrides
  };
}
