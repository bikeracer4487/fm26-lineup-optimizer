import { useState, useEffect, useCallback } from 'react';
import type { AppState, Match } from '../types';
import { api } from '../api';

const DEFAULT_STATE: AppState = {
  currentDate: new Date().toISOString().split('T')[0],
  matches: [],
  rejectedPlayers: {},
  rejectedTraining: {},
  files: {
    status: 'players-current.csv',
    abilities: 'players.csv'
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
          setState(loaded);
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
    save({ ...state, matches });
  };

  const updateRejectedPlayers = (matchIndex: string, players: string[]) => {
    save({
      ...state,
      rejectedPlayers: {
        ...state.rejectedPlayers,
        [matchIndex]: players
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
    updateFiles
  };
}
