import { useState, useEffect, useMemo } from 'react';
import { X, Search } from 'lucide-react';
import { motion, AnimatePresence } from 'framer-motion';
import type { PlayerListItem } from '../types';
import { api } from '../api';

interface PlayerSelectModalProps {
  isOpen: boolean;
  onClose: () => void;
  onSelect: (playerName: string) => void;
  position: string;
  excludedPlayers: string[];
  playersInPositions?: Record<string, string>;  // playerName -> position (for visual indicator)
  statusFile?: string;
}

export function PlayerSelectModal({
  isOpen,
  onClose,
  onSelect,
  position,
  excludedPlayers,
  playersInPositions,
  statusFile = 'players-current.csv'
}: PlayerSelectModalProps) {
  const [players, setPlayers] = useState<PlayerListItem[]>([]);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [search, setSearch] = useState('');

  useEffect(() => {
    if (isOpen) {
      setLoading(true);
      setError(null);
      setSearch('');

      api.getPlayerList(statusFile)
        .then(response => {
          if (response.success && response.players) {
            setPlayers(response.players);
          } else {
            setError(response.error || 'Failed to load players');
          }
        })
        .catch(err => {
          setError(String(err));
        })
        .finally(() => {
          setLoading(false);
        });
    }
  }, [isOpen, statusFile]);

  const filteredPlayers = useMemo(() => {
    const excludedSet = new Set(excludedPlayers.map(p => p.toLowerCase()));

    return players.filter(player => {
      // Filter out excluded players
      if (excludedSet.has(player.name.toLowerCase())) {
        return false;
      }

      // Filter by search term
      if (search) {
        const searchLower = search.toLowerCase();
        return (
          player.name.toLowerCase().includes(searchLower) ||
          player.position.toLowerCase().includes(searchLower)
        );
      }

      return true;
    });
  }, [players, excludedPlayers, search]);

  const handleSelect = (playerName: string) => {
    onSelect(playerName);
    onClose();
  };

  if (!isOpen) return null;

  return (
    <AnimatePresence>
      <div className="fixed inset-0 z-50 flex items-center justify-center">
        {/* Backdrop */}
        <motion.div
          initial={{ opacity: 0 }}
          animate={{ opacity: 1 }}
          exit={{ opacity: 0 }}
          className="absolute inset-0 bg-black/60 backdrop-blur-sm"
          onClick={onClose}
        />

        {/* Modal */}
        <motion.div
          initial={{ opacity: 0, scale: 0.95 }}
          animate={{ opacity: 1, scale: 1 }}
          exit={{ opacity: 0, scale: 0.95 }}
          className="relative bg-fm-surface border border-white/10 rounded-xl shadow-2xl w-full max-w-md max-h-[80vh] flex flex-col"
        >
          {/* Header */}
          <div className="p-4 border-b border-white/10 flex items-center justify-between">
            <div>
              <h3 className="text-lg font-bold text-white">Select Player</h3>
              <p className="text-sm text-fm-light/50">
                Override {position} position
              </p>
            </div>
            <button
              onClick={onClose}
              className="text-fm-light/50 hover:text-white transition-colors p-1"
            >
              <X size={20} />
            </button>
          </div>

          {/* Search */}
          <div className="p-4 border-b border-white/10">
            <div className="relative">
              <Search size={16} className="absolute left-3 top-1/2 -translate-y-1/2 text-fm-light/50" />
              <input
                type="text"
                placeholder="Search by name or position..."
                value={search}
                onChange={e => setSearch(e.target.value)}
                className="w-full bg-white/5 border border-white/10 rounded-lg py-2 pl-10 pr-4 text-white placeholder-fm-light/30 focus:outline-none focus:border-fm-teal/50"
                autoFocus
              />
            </div>
          </div>

          {/* Player List */}
          <div className="flex-1 overflow-y-auto p-2">
            {loading && (
              <div className="flex justify-center py-8">
                <div className="animate-spin rounded-full h-8 w-8 border-b-2 border-fm-teal"></div>
              </div>
            )}

            {error && (
              <div className="text-center text-fm-danger py-8">
                {error}
              </div>
            )}

            {!loading && !error && filteredPlayers.length === 0 && (
              <div className="text-center text-fm-light/50 py-8">
                No available players found
              </div>
            )}

            {!loading && !error && filteredPlayers.length > 0 && (
              <div className="space-y-1">
                {filteredPlayers.map(player => {
                  const currentPosition = playersInPositions?.[player.name];
                  return (
                    <button
                      key={player.name}
                      onClick={() => handleSelect(player.name)}
                      className="w-full flex items-center justify-between px-3 py-2 rounded-lg hover:bg-white/10 transition-colors text-left group"
                    >
                      <div className="flex items-center gap-2">
                        <span className="text-white font-medium group-hover:text-fm-teal transition-colors">
                          {player.name}
                        </span>
                        {currentPosition && (
                          <span className="text-xs px-1.5 py-0.5 rounded bg-fm-amber/20 text-fm-amber">
                            in {currentPosition}
                          </span>
                        )}
                      </div>
                      <span className="text-fm-light/50 text-sm">
                        {player.position}
                      </span>
                    </button>
                  );
                })}
              </div>
            )}
          </div>

          {/* Footer */}
          <div className="p-4 border-t border-white/10 text-center text-fm-light/40 text-xs">
            {filteredPlayers.length} players available
          </div>
        </motion.div>
      </div>
    </AnimatePresence>
  );
}
