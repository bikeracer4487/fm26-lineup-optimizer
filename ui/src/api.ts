import type { AppState, MatchPlanResponse, TrainingResponse, RestResponse, PlayerRemovalResponse, RotationResponse, PlayerListItem, ConfirmedLineup, ConfirmedLineupsData, TacticConfig } from './types';

// Type definition for window.ipcRenderer
declare global {
  interface Window {
    ipcRenderer: {
      invoke(channel: string, ...args: any[]): Promise<any>;
    };
  }
}

export const api = {
  getAppState: async (): Promise<AppState | null> => {
    return await window.ipcRenderer.invoke('get-app-state');
  },

  saveAppState: async (state: AppState): Promise<{ success: boolean; error?: string }> => {
    return await window.ipcRenderer.invoke('save-app-state', state);
  },

  runMatchSelector: async (
    matches: any[],
    rejected: Record<string, string[]>,
    files: { status: string; abilities: string },
    tacticConfig?: TacticConfig
  ): Promise<MatchPlanResponse> => {
    return await window.ipcRenderer.invoke('run-match-selector', { matches, rejected, files, tacticConfig });
  },

  runTrainingAdvisor: async (
    rejected: Record<string, string>,
    files: { status: string; abilities: string }
  ): Promise<TrainingResponse> => {
    return await window.ipcRenderer.invoke('run-training-advisor', { rejected, files });
  },

  runRestAdvisor: async (
    files: { status: string; abilities: string }
  ): Promise<RestResponse> => {
    return await window.ipcRenderer.invoke('run-rest-advisor', { files });
  },

  runPlayerRemovalAdvisor: async (
    files: { status: string; abilities: string }
  ): Promise<PlayerRemovalResponse> => {
    return await window.ipcRenderer.invoke('run-player-removal-advisor', { files });
  },

  runRotationSelector: async (
    files: { status: string; abilities: string }
  ): Promise<RotationResponse> => {
    return await window.ipcRenderer.invoke('run-rotation-selector', { files });
  },

  // Get player list for override modal
  getPlayerList: async (
    statusFile: string = 'players-current.csv'
  ): Promise<{ success: boolean; players?: PlayerListItem[]; error?: string }> => {
    return await window.ipcRenderer.invoke('get-player-list', { statusFile });
  },

  // Confirmed lineups management
  getConfirmedLineups: async (): Promise<ConfirmedLineupsData> => {
    return await window.ipcRenderer.invoke('get-confirmed-lineups');
  },

  saveConfirmedLineup: async (
    lineup: ConfirmedLineup
  ): Promise<{ success: boolean; error?: string }> => {
    return await window.ipcRenderer.invoke('save-confirmed-lineup', lineup);
  },

  removeConfirmedLineup: async (
    matchId: string
  ): Promise<{ success: boolean; error?: string }> => {
    return await window.ipcRenderer.invoke('remove-confirmed-lineup', matchId);
  }
};
