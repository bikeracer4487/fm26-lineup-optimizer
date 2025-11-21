import type { AppState, MatchPlanResponse, TrainingResponse, RestResponse } from './types';

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
    files: { status: string; abilities: string }
  ): Promise<MatchPlanResponse> => {
    return await window.ipcRenderer.invoke('run-match-selector', { matches, rejected, files });
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
  }
};
