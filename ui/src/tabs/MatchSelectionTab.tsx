import React, { useState, useEffect } from 'react';
import type { AppState, MatchPlanItem, MatchSelectionPlayer } from '../types';
import { api } from '../api';
import { Button, Card, Badge } from '../components/UI';
import { RefreshCw, UserX, AlertTriangle, Star, Activity, Battery, Zap, ChevronDown, ChevronRight } from 'lucide-react';
import { motion, AnimatePresence } from 'framer-motion';

interface MatchSelectionTabProps {
  state: AppState;
  onRejectPlayer: (matchIndex: string, players: string[]) => void;
  onResetRejections: () => void;
}

export function MatchSelectionTab({ state, onRejectPlayer, onResetRejections }: MatchSelectionTabProps) {
  const [plan, setPlan] = useState<MatchPlanItem[] | null>(null);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [showPast, setShowPast] = useState(false);

  const generatePlan = async () => {
    if (state.matches.length === 0) {
      setError("No matches scheduled. Please add matches in the Fixture List.");
      return;
    }

    setLoading(true);
    setError(null);
    
    try {
      const response = await api.runMatchSelector(
        state.matches,
        state.rejectedPlayers,
        state.files
      );

      if (response.success && response.plan) {
        setPlan(response.plan);
      } else {
        setError(response.error || "Failed to generate plan");
      }
    } catch (err) {
      setError(String(err));
    } finally {
      setLoading(false);
    }
  };

  // Auto-run when dependencies change (debounced ideally, but simple effect for now)
  useEffect(() => {
    // Only run if we have matches
    if (state.matches.length > 0) {
      const timer = setTimeout(generatePlan, 100); // Small delay to prevent double-fires
      return () => clearTimeout(timer);
    }
  }, [state.matches, state.rejectedPlayers, state.files]);

  const handleReject = (matchIndex: number, playerName: string) => {
    const indexStr = String(matchIndex);
    const currentRejected = state.rejectedPlayers[indexStr] || [];
    if (!currentRejected.includes(playerName)) {
      onRejectPlayer(indexStr, [...currentRejected, playerName]);
    }
  };

  const sortedPlan = plan 
    ? [...plan].sort((a, b) => {
        if (a.date && b.date) {
          const compare = a.date.localeCompare(b.date);
          if (compare !== 0) return compare;
        } else if (a.date) {
          return -1;
        } else if (b.date) {
          return 1;
        }
        return a.matchIndex - b.matchIndex;
      })
    : [];

  // Filter plan items based on current date
  const upcomingMatches = sortedPlan.filter(item => item.date >= state.currentDate);
  const pastMatches = sortedPlan.filter(item => item.date < state.currentDate).reverse();

  return (
    <div className="p-6 space-y-6">
      <div className="flex items-center justify-between">
        <h2 className="text-2xl font-bold text-white">Match Selection</h2>
        <div className="flex gap-2">
          <Button variant="secondary" size="sm" onClick={onResetRejections} title="Clear all manual rejections">
            Reset Rejections
          </Button>
          <Button onClick={generatePlan} disabled={loading} size="sm" className="flex items-center whitespace-nowrap">
            <RefreshCw size={16} className={loading ? "animate-spin mr-2" : "mr-2"} />
            Refresh
          </Button>
        </div>
      </div>

      {error && (
        <div className="bg-fm-danger/10 border border-fm-danger text-fm-danger p-4 rounded-md flex items-center gap-2">
          <AlertTriangle size={20} />
          {error}
        </div>
      )}

      {loading && !plan && (
        <div className="flex justify-center py-20">
          <div className="animate-spin rounded-full h-12 w-12 border-b-2 border-fm-teal"></div>
        </div>
      )}

      <div className="space-y-8">
        {upcomingMatches.length > 0 && (
          <div className="space-y-8">
            {upcomingMatches.map((item) => (
              <MatchCard 
                key={item.matchIndex} 
                item={item} 
                onReject={(name) => handleReject(item.matchIndex, name)}
                opponent={state.matches[item.matchIndex]?.opponent || "Unknown"}
              />
            ))}
          </div>
        )}

        {pastMatches.length > 0 && (
          <div className="pt-6 border-t border-white/5">
            <button 
                onClick={() => setShowPast(!showPast)}
                className="flex items-center gap-2 text-fm-light/50 hover:text-white transition-colors text-sm font-bold uppercase tracking-wider mb-4 w-full text-left"
            >
                {showPast ? <ChevronDown size={16} /> : <ChevronRight size={16} />}
                Past Matches Archive ({pastMatches.length})
            </button>

            {showPast && (
              <div className="space-y-8 opacity-75 grayscale-[0.5]">
                {pastMatches.map((item) => (
                  <MatchCard 
                    key={item.matchIndex} 
                    item={item} 
                    onReject={(name) => handleReject(item.matchIndex, name)}
                    opponent={state.matches[item.matchIndex]?.opponent || "Unknown"}
                  />
                ))}
              </div>
            )}
          </div>
        )}
        
        {!loading && (!plan || plan.length === 0) && !error && (
            <div className="text-center text-fm-light/50 py-12">
                Add matches to the fixture list to generate a plan.
            </div>
        )}
      </div>
    </div>
  );
}

function MatchCard({ item, onReject, opponent }: { item: MatchPlanItem, onReject: (name: string) => void, opponent: string }) {
  const positions = [
    'GK', 
    'DR', 'DC1', 'DC2', 'DL',
    'DM(R)', 'DM(L)',
    'AMR', 'AMC', 'AML',
    'STC'
  ];

  // Helper to find player in selection by position key
  const getPlayer = (pos: string) => item.selection[pos];

  return (
    <motion.div
      initial={{ opacity: 0, y: 20 }}
      animate={{ opacity: 1, y: 0 }}
      className="bg-fm-surface rounded-xl overflow-hidden shadow-xl border border-white/5"
    >
      <div className="bg-fm-dark/40 p-4 flex items-center border-b border-white/5">
        <div>
          <h3 className="text-lg font-bold text-white">{item.date} vs {opponent}</h3>
          <div className="flex gap-2 mt-1">
            <Badge variant={item.importance === 'High' ? 'danger' : item.importance === 'Medium' ? 'warning' : 'success'}>
              {item.importance} Priority
            </Badge>
          </div>
        </div>
      </div>

      <div className="p-4 grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4 gap-3">
        {positions.map(pos => {
          const player = getPlayer(pos);
          if (!player) return null;
          
          return (
            <PlayerCard 
              key={pos} 
              pos={pos} 
              player={player} 
              onReject={() => onReject(player.name)} 
            />
          );
        })}
      </div>
    </motion.div>
  );
}

function PlayerCard({ pos, player, onReject }: { pos: string, player: MatchSelectionPlayer, onReject: () => void }) {
  
  const getStatusColor = (status: string) => {
    const lowerStatus = status.toLowerCase();
    if (lowerStatus.includes('vacation') || lowerStatus.includes('fatigued') || lowerStatus.includes('injury') || lowerStatus.includes('low condition')) {
      return "bg-red-500/10 text-red-500 border-red-500/20";
    }
    if (lowerStatus.includes('risk') || lowerStatus.includes('sharpness') || lowerStatus.includes('low')) {
      return "bg-yellow-500/10 text-yellow-500 border-yellow-500/20";
    }
    if (lowerStatus.includes('peak') || lowerStatus.includes('form')) {
      return "bg-green-500/10 text-green-500 border-green-500/20";
    }
    return "bg-blue-500/10 text-blue-400 border-blue-500/20";
  };

  return (
    <div className="bg-white/5 rounded-lg p-3 border border-white/5 hover:border-fm-teal/30 transition-colors group relative">
      <div className="flex justify-between items-start mb-2">
        <span className="text-xs font-bold text-fm-teal bg-fm-teal/10 px-1.5 py-0.5 rounded">{pos}</span>
        <button 
          onClick={onReject}
          className="text-fm-light/30 hover:text-fm-danger transition-colors opacity-0 group-hover:opacity-100"
          title="Reject from lineup"
        >
          <UserX size={14} />
        </button>
      </div>
      
      <div className="font-bold text-white truncate mb-1" title={player.name}>{player.name}</div>
      
      <div className="flex gap-3 text-xs text-fm-light/70 mb-2">
        <div className="flex items-center gap-1" title="Condition">
           <Battery size={12} className={player.condition < 0.9 ? "text-fm-danger" : "text-fm-success"} />
           {Math.round(player.condition * 100)}%
        </div>
        <div className="flex items-center gap-1" title="Match Sharpness">
           <Activity size={12} className={player.sharpness < 0.8 ? "text-yellow-500" : "text-fm-success"} />
           {Math.round(player.sharpness * 100)}%
        </div>
        {player.fatigue > 0 && (
             <div className="flex items-center gap-1" title="Fatigue">
             <Zap size={12} className={player.fatigue > 400 ? "text-fm-danger" : "text-fm-light"} />
             {player.fatigue}
          </div>
        )}
      </div>

      {player.status && player.status.length > 0 && (
        <div className="flex flex-wrap gap-1">
          {player.status.map((s, i) => (
            <span key={i} className={`text-[10px] px-1 rounded border ${getStatusColor(s)}`}>
              {s}
            </span>
          ))}
        </div>
      )}
    </div>
  );
}
