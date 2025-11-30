import React, { useState, useEffect } from 'react';
import type { AppState, RestRecommendation } from '../types';
import { api } from '../api';
import { Button, Badge } from '../components/UI';
import { RefreshCw, Battery, BatteryCharging, BatteryWarning, Zap, Activity, HeartPulse, AlertTriangle, Plane } from 'lucide-react';
import { motion } from 'framer-motion';

interface RestTabProps {
  state: AppState;
}

export function RestTab({ state }: RestTabProps) {
  const [recommendations, setRecommendations] = useState<RestRecommendation[]>([]);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const loadRecommendations = async () => {
    setLoading(true);
    setError(null);
    try {
      const response = await api.runRestAdvisor(state.files);
      
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
  }, [state.files]);

  const grouped = {
    Urgent: recommendations.filter(r => r.priority === 'Urgent'),
    High: recommendations.filter(r => r.priority === 'High'),
    Medium: recommendations.filter(r => r.priority === 'Medium'),
    Low: recommendations.filter(r => r.priority === 'Low'),
  };

  return (
    <div className="p-6 space-y-6">
      <div className="flex items-center justify-between">
        <h2 className="text-2xl font-bold text-white flex items-center gap-2">
          <BatteryCharging className="text-fm-teal" /> Rest & Rotation
        </h2>
        <Button onClick={loadRecommendations} disabled={loading} size="sm" className="flex items-center whitespace-nowrap">
          <RefreshCw size={16} className={loading ? "animate-spin mr-2" : "mr-2"} />
          Refresh
        </Button>
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
        {grouped.Urgent.length > 0 && (
          <RestGroup 
            title="URGENT ACTION NEEDED" 
            items={grouped.Urgent} 
            color="text-fm-danger" 
            icon={<AlertTriangle size={20} />}
          />
        )}
        {grouped.High.length > 0 && (
          <RestGroup 
            title="High Priority" 
            items={grouped.High} 
            color="text-orange-500" 
            icon={<BatteryWarning size={20} />}
          />
        )}
        {grouped.Medium.length > 0 && (
          <RestGroup 
            title="Medium Priority" 
            items={grouped.Medium} 
            color="text-yellow-500" 
            icon={<Battery size={20} />}
          />
        )}
        {grouped.Low.length > 0 && (
          <RestGroup 
            title="Monitor" 
            items={grouped.Low} 
            color="text-fm-success" 
            icon={<Activity size={20} />}
          />
        )}

        {!loading && recommendations.length === 0 && !error && (
            <div className="text-center text-fm-light/50 py-12">
                No rest recommendations needed. Squad is fresh!
            </div>
        )}
      </div>
    </div>
  );
}

function RestGroup({ title, items, color, icon }: { title: string, items: RestRecommendation[], color: string, icon: React.ReactNode }) {
  return (
    <div className="space-y-3">
      <h3 className={`text-lg font-bold ${color} flex items-center gap-2 uppercase tracking-wider`}>
        {icon} {title}
      </h3>
      <div className="grid grid-cols-1 lg:grid-cols-2 gap-4">
        {items.map((rec) => (
          <RestCard key={rec.name} rec={rec} />
        ))}
      </div>
    </div>
  );
}

function RestCard({ rec }: { rec: RestRecommendation }) {
  const isVacation = rec.action.toLowerCase().includes('vacation');

  return (
    <motion.div 
      initial={{ opacity: 0, scale: 0.95 }}
      animate={{ opacity: 1, scale: 1 }}
      className="bg-fm-surface p-4 rounded-lg border border-white/5 hover:border-fm-teal/30 transition-all group relative overflow-hidden"
    >
      {/* Background indicators */}
      {isVacation && (
        <div className="absolute -right-8 -top-8 w-24 h-24 bg-orange-500/10 rotate-45 blur-xl pointer-events-none"></div>
      )}

      <div className="flex justify-between items-start relative z-10">
        <div>
          <div className="flex items-center gap-2">
            <div className="text-lg font-bold text-white">{rec.name}</div>
            <Badge className={`
              ${rec.priority === 'Urgent' ? 'bg-fm-danger/20 text-fm-danger' : 
                rec.priority === 'High' ? 'bg-orange-500/20 text-orange-400' : 
                rec.priority === 'Medium' ? 'bg-yellow-500/20 text-yellow-400' : 
                'bg-fm-success/20 text-fm-success'}
            `}>
              {rec.status}
            </Badge>
          </div>
          
          <div className="flex items-center gap-2 mt-2">
            <span className="text-fm-light/70 text-sm font-bold">Recommendation:</span>
            <Badge className={`flex items-center gap-1 ${isVacation ? 'bg-blue-500/20 text-blue-400 border-blue-500/30' : 'bg-fm-dark/50 text-white border-white/10'}`}>
               {isVacation && <Plane size={12} />}
               {rec.action}
            </Badge>
          </div>
        </div>
      </div>

      <div className="mt-4 grid grid-cols-3 gap-2 relative z-10">
        <div className="bg-fm-dark/30 p-2 rounded border border-white/5">
          <div className="text-[10px] text-fm-light/50 uppercase font-bold mb-1 flex items-center gap-1">
            <Zap size={10} /> Fatigue
          </div>
          <div className={`text-lg font-mono font-bold ${rec.fatigue >= rec.threshold ? 'text-fm-danger' : 'text-white'}`}>
            {rec.fatigue.toFixed(0)} <span className="text-[10px] text-fm-light/30">/ {rec.threshold.toFixed(0)}</span>
          </div>
        </div>
        
        <div className="bg-fm-dark/30 p-2 rounded border border-white/5">
          <div className="text-[10px] text-fm-light/50 uppercase font-bold mb-1 flex items-center gap-1">
            <HeartPulse size={10} /> Condition
          </div>
          <div className={`text-lg font-mono font-bold ${rec.condition < 85 ? 'text-fm-danger' : 'text-white'}`}>
            {rec.condition.toFixed(0)}%
          </div>
        </div>

        <div className="bg-fm-dark/30 p-2 rounded border border-white/5">
          <div className="text-[10px] text-fm-light/50 uppercase font-bold mb-1 flex items-center gap-1">
            <Activity size={10} /> Sharpness
          </div>
          <div className={`text-lg font-mono font-bold ${rec.sharpness < 0.8 ? 'text-yellow-500' : 'text-white'}`}>
            {(rec.sharpness * 100).toFixed(0)}%
          </div>
        </div>
      </div>

      <div className="mt-3 pt-3 border-t border-white/5 space-y-1 relative z-10">
        {rec.reasons.map((reason, idx) => (
          <div key={idx} className="text-xs text-fm-light/70 flex items-start gap-2">
            <span className="text-fm-teal mt-0.5">→</span>
            {reason}
          </div>
        ))}
      </div>
    </motion.div>
  );
}

