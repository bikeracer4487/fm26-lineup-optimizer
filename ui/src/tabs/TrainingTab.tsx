import { useState, useEffect } from 'react';
import type { AppState, TrainingRecommendation } from '../types';
import { api } from '../api';
import { Button, Badge } from '../components/UI';
import { RefreshCw, XCircle, TrendingUp, Target, BookOpen, Clock, Zap } from 'lucide-react';
import { motion } from 'framer-motion';

interface TrainingTabProps {
  state: AppState;
  onRejectTraining: (player: string, position: string) => void;
  onResetRejections: () => void;
}

export function TrainingTab({ state, onRejectTraining, onResetRejections }: TrainingTabProps) {
  const [recommendations, setRecommendations] = useState<TrainingRecommendation[]>([]);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const loadRecommendations = async () => {
    setLoading(true);
    setError(null);
    try {
      const response = await api.runTrainingAdvisor(
        state.rejectedTraining,
        state.files
      );
      
      if (response.success && response.recommendations) {
        setRecommendations(response.recommendations);
      } else {
        setError(response.error || "Failed to load recommendations");
      }
    } catch (err) {
      setError(String(err));
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    loadRecommendations();
  }, [state.rejectedTraining, state.files]);

  const grouped = {
    High: recommendations.filter(r => r.priority === 'High'),
    Medium: recommendations.filter(r => r.priority === 'Medium'),
    Low: recommendations.filter(r => r.priority === 'Low'),
  };

  return (
    <div className="p-6 space-y-6">
      <div className="flex items-center justify-between">
        <h2 className="text-2xl font-bold text-white">Position Training</h2>
        <div className="flex gap-2">
          <Button variant="secondary" size="sm" onClick={onResetRejections}>
            Reset Rejections
          </Button>
          <Button onClick={loadRecommendations} disabled={loading} size="sm" className="flex items-center whitespace-nowrap">
            <RefreshCw size={16} className={loading ? "animate-spin mr-2" : "mr-2"} />
            Refresh
          </Button>
        </div>
      </div>

      {error && (
        <div className="bg-fm-danger/10 border border-fm-danger text-fm-danger p-4 rounded-md">
          {error}
        </div>
      )}

      {loading && !recommendations.length && (
        <div className="flex justify-center py-20">
          <div className="animate-spin rounded-full h-12 w-12 border-b-2 border-fm-teal"></div>
        </div>
      )}

      <div className="space-y-8">
        {grouped.High.length > 0 && (
          <TrainingGroup 
            title="High Priority" 
            items={grouped.High} 
            color="text-fm-danger" 
            onReject={onRejectTraining} 
          />
        )}
        {grouped.Medium.length > 0 && (
          <TrainingGroup 
            title="Medium Priority" 
            items={grouped.Medium} 
            color="text-yellow-500" 
            onReject={onRejectTraining} 
          />
        )}
        {grouped.Low.length > 0 && (
          <TrainingGroup 
            title="Low Priority" 
            items={grouped.Low} 
            color="text-fm-success" 
            onReject={onRejectTraining} 
          />
        )}

        {!loading && recommendations.length === 0 && !error && (
            <div className="text-center text-fm-light/50 py-12">
                No training recommendations found. Squad coverage is good!
            </div>
        )}
      </div>
    </div>
  );
}

function TrainingGroup({ title, items, color, onReject }: { title: string, items: TrainingRecommendation[], color: string, onReject: (p: string, pos: string) => void }) {
  return (
    <div className="space-y-3">
      <h3 className={`text-lg font-bold ${color} flex items-center gap-2`}>
        <Target size={18} /> {title}
      </h3>
      <div className="grid grid-cols-1 lg:grid-cols-2 gap-4">
        {items.map((rec) => (
          <TrainingCard key={`${rec.player}-${rec.position}`} rec={rec} onReject={onReject} />
        ))}
      </div>
    </div>
  );
}

function TrainingCard({ rec, onReject }: { rec: TrainingRecommendation, onReject: (p: string, pos: string) => void }) {
  // Check for strategic categories
  const isStrategic = rec.strategic_category && rec.strategic_category !== 'Standard';
  const isPipeline = isStrategic && rec.strategic_category?.includes('Pipeline');
  
  return (
    <motion.div 
      initial={{ opacity: 0, scale: 0.95 }}
      animate={{ opacity: 1, scale: 1 }}
      className="bg-fm-surface p-4 rounded-lg border border-white/5 hover:border-fm-teal/30 transition-all group relative overflow-hidden"
    >
      {/* Background indicators for special statuses */}
      {isPipeline && (
        <div className="absolute -right-8 -top-8 w-24 h-24 bg-purple-500/10 rotate-45 blur-xl pointer-events-none"></div>
      )}
      {rec.is_universalist && (
        <div className="absolute -right-8 -bottom-8 w-24 h-24 bg-blue-500/10 rotate-45 blur-xl pointer-events-none"></div>
      )}

      <div className="flex justify-between items-start relative z-10">
        <div>
          <div className="flex items-center gap-2">
            <div className="text-lg font-bold text-white">{rec.player}</div>
            {rec.is_universalist && (
              <Badge variant="info" className="text-[10px] px-1 h-5 flex items-center" title={`Covers ${rec.universalist_coverage} positions`}>
                UTIL
              </Badge>
            )}
            {rec.fills_variety_gap && (
              <Badge variant="warning" className="text-[10px] px-1 h-5 flex items-center" title="Fills a tactical variety gap">
                VAR
              </Badge>
            )}
          </div>
          
          <div className="flex items-center gap-2 mt-1">
            <span className="text-fm-light/70 text-sm">Train as:</span>
            <Badge className="bg-fm-teal/20 text-fm-teal border-fm-teal/30">{rec.position}</Badge>
            
            {isStrategic && (
               <Badge className="bg-purple-500/20 text-purple-400 border-purple-500/30 text-[10px]">
                 {isPipeline ? 'STRATEGIC PIPELINE' : 'STRATEGIC'}
               </Badge>
            )}
          </div>
        </div>
        <button 
          onClick={() => onReject(rec.player, rec.position)}
          className="text-fm-light/30 hover:text-fm-danger transition-colors p-1"
          title="Reject Recommendation"
        >
          <XCircle size={18} />
        </button>
      </div>

      <div className="mt-3 grid grid-cols-2 gap-3 text-xs text-fm-light/70 relative z-10">
        <div>
          <span className="block text-fm-light/40 flex items-center gap-1">
             <Clock size={10} /> Estimated Timeline
          </span>
          <span className="font-medium text-white">{rec.estimated_timeline || 'Unknown'}</span>
        </div>
        
        <div>
          <span className="block text-fm-light/40">Potential Ability</span>
          <span className="font-medium text-white">
            {rec.ability_tier} 
            {rec.ability_rating ? ` (${rec.ability_rating.toFixed(0)})` : ''}
          </span>
        </div>
        
        <div>
           <span className="block text-fm-light/40">Category</span>
           <span className="font-medium text-white flex items-center gap-1 truncate" title={rec.strategic_category}>
             {rec.category === 'Become Natural' ? <TrendingUp size={10} /> : <BookOpen size={10} />}
             {isStrategic ? 'Strategic Conversion' : rec.category}
           </span>
        </div>
        
        <div>
          <span className="block text-fm-light/40 flex items-center gap-1">
            <Zap size={10} /> Training Score
          </span>
          <span className="font-medium text-white">{rec.training_score.toFixed(2)}</span>
        </div>
      </div>

      <div className="mt-3 pt-3 border-t border-white/5 text-xs text-fm-light/60 italic relative z-10">
        "{rec.reason}"
      </div>
    </motion.div>
  );
}
