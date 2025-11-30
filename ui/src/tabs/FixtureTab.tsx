import { useState } from 'react';
import type { Match } from '../types';
import { Button, Card, Input, Select } from '../components/UI';
import { Trash2, Plus, Calendar, ChevronDown, ChevronRight } from 'lucide-react';
import { motion, AnimatePresence } from 'framer-motion';

interface FixtureTabProps {
  matches: Match[];
  onUpdateMatches: (matches: Match[]) => void;
  currentDate: string;
}

export function FixtureTab({ matches, onUpdateMatches, currentDate }: FixtureTabProps) {
  const [newMatch, setNewMatch] = useState<Partial<Match>>({
    date: '',
    opponent: '',
    importance: 'Medium'
  });
  
  const [showPast, setShowPast] = useState(false);

  const addMatch = () => {
    if (!newMatch.date || !newMatch.opponent) return;
    
    const match: Match = {
      id: crypto.randomUUID(),
      date: newMatch.date,
      opponent: newMatch.opponent,
      importance: (newMatch.importance as any) || 'Medium'
    };
    
    const updated = [...matches, match].sort((a, b) => a.date.localeCompare(b.date));
    onUpdateMatches(updated);
    setNewMatch({ date: '', opponent: '', importance: 'Medium' });
  };

  const removeMatch = (id: string) => {
    onUpdateMatches(matches.filter(m => m.id !== id));
  };

  const updateMatch = (id: string, field: keyof Match, value: string) => {
    const updatedMatches = matches.map(m => m.id === id ? { ...m, [field]: value } : m);
    const sortedMatches = field === 'date' 
      ? [...updatedMatches].sort((a, b) => a.date.localeCompare(b.date))
      : updatedMatches;
    onUpdateMatches(sortedMatches);
  };

  // Separate past and upcoming matches
  const upcomingMatches = matches.filter(m => m.date >= currentDate);
  const pastMatches = matches.filter(m => m.date < currentDate).reverse(); // Most recent past match first

  return (
    <div className="space-y-6 p-6">
      <div className="flex items-center justify-between">
        <h2 className="text-2xl font-bold text-white">Fixture List</h2>
        <div className="text-fm-light/70 text-sm flex items-center gap-2">
          <Calendar size={16} />
          Current Date: {currentDate}
        </div>
      </div>

      <Card className="bg-fm-surface/50 border-dashed border-white/20">
        <div className="grid grid-cols-12 gap-4 items-end">
          <div className="col-span-3">
            <label className="block text-xs text-fm-light mb-1">Date</label>
            <Input 
              type="date" 
              className="w-full" 
              value={newMatch.date} 
              onChange={e => setNewMatch({...newMatch, date: e.target.value})} 
            />
          </div>
          <div className="col-span-5">
            <label className="block text-xs text-fm-light mb-1">Opponent</label>
            <Input 
              type="text" 
              className="w-full" 
              placeholder="Opponent Name"
              value={newMatch.opponent} 
              onChange={e => setNewMatch({...newMatch, opponent: e.target.value})} 
            />
          </div>
          <div className="col-span-3">
            <label className="block text-xs text-fm-light mb-1">Importance</label>
            <Select 
              className="w-full" 
              value={newMatch.importance} 
              onChange={e => setNewMatch({...newMatch, importance: e.target.value as any})} 
            >
              <option value="Low">Low</option>
              <option value="Medium">Medium</option>
              <option value="High">High</option>
              <option value="Sharpness">Sharpness</option>
            </Select>
          </div>
          <div className="col-span-1">
            <Button onClick={addMatch} className="w-full flex justify-center">
              <Plus size={20} />
            </Button>
          </div>
        </div>
      </Card>

      {/* Upcoming Matches */}
      <div className="space-y-3">
        <h3 className="text-fm-light/50 text-sm font-bold uppercase tracking-wider">Upcoming Matches</h3>
        <AnimatePresence mode="popLayout">
          {upcomingMatches.map((match) => (
            <MatchRow 
                key={match.id} 
                match={match} 
                onUpdate={updateMatch} 
                onRemove={removeMatch} 
            />
          ))}
        </AnimatePresence>
        
        {upcomingMatches.length === 0 && (
          <div className="text-center py-8 text-fm-light/30 italic bg-white/5 rounded-lg border border-white/5">
            No upcoming matches scheduled.
          </div>
        )}
      </div>

      {/* Past Matches Archive */}
      {pastMatches.length > 0 && (
        <div className="pt-6 border-t border-white/5">
            <button 
                onClick={() => setShowPast(!showPast)}
                className="flex items-center gap-2 text-fm-light/50 hover:text-white transition-colors text-sm font-bold uppercase tracking-wider mb-4 w-full text-left"
            >
                {showPast ? <ChevronDown size={16} /> : <ChevronRight size={16} />}
                Past Matches Archive ({pastMatches.length})
            </button>

            <AnimatePresence>
                {showPast && (
                    <motion.div 
                        initial={{ height: 0, opacity: 0 }}
                        animate={{ height: 'auto', opacity: 1 }}
                        exit={{ height: 0, opacity: 0 }}
                        className="space-y-3 overflow-hidden"
                    >
                        {pastMatches.map((match) => (
                            <MatchRow 
                                key={match.id} 
                                match={match} 
                                onUpdate={updateMatch} 
                                onRemove={removeMatch} 
                                isPast
                            />
                        ))}
                    </motion.div>
                )}
            </AnimatePresence>
        </div>
      )}
    </div>
  );
}

function MatchRow({ match, onUpdate, onRemove, isPast }: { match: Match, onUpdate: any, onRemove: any, isPast?: boolean }) {
    return (
        <motion.div
            layout
            initial={{ opacity: 0, y: 20 }}
            animate={{ opacity: 1, y: 0 }}
            exit={{ opacity: 0, x: -20 }}
            transition={{ duration: 0.2 }}
        >
            <Card className={`flex items-center gap-4 p-3 hover:bg-white/5 transition-colors group ${isPast ? 'opacity-60 grayscale' : ''}`}>
            <Input 
                type="date" 
                className="w-40 bg-transparent border-transparent focus:bg-fm-dark/50 focus:border-fm-teal" 
                value={match.date} 
                onChange={e => onUpdate(match.id, 'date', e.target.value)}
            />
            <Input 
                type="text" 
                className="flex-1 bg-transparent border-transparent focus:bg-fm-dark/50 focus:border-fm-teal font-medium text-lg" 
                value={match.opponent} 
                onChange={e => onUpdate(match.id, 'opponent', e.target.value)}
            />
                <Select
                className="w-32 bg-transparent border-transparent focus:bg-fm-dark/50 focus:border-fm-teal text-sm"
                value={match.importance}
                onChange={e => onUpdate(match.id, 'importance', e.target.value)}
            >
                <option value="Low">Low</option>
                <option value="Medium">Medium</option>
                <option value="High">High</option>
                <option value="Sharpness">Sharpness</option>
            </Select>
            
            <Button 
                variant="ghost" 
                size="sm" 
                onClick={() => onRemove(match.id)}
                className="opacity-0 group-hover:opacity-100 text-fm-danger hover:bg-fm-danger/10"
            >
                <Trash2 size={18} />
            </Button>
            </Card>
        </motion.div>
    );
}
