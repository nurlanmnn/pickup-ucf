import { useState, useEffect } from 'react';
import { supabase } from '../lib/supabase';

export interface Session {
  id: string;
  sport: string;
  custom_sport?: string;
  title?: string;
  notes?: string;
  starts_at: string;
  ends_at: string;
  address?: string;
  capacity: number;
  is_indoor: boolean;
  skill_target: string;
  positions?: string[];
  equipment_needed: boolean;
  host_id: string;
  is_open: boolean;
  created_at: string;
  spots_left?: number;
}

export function useFeed() {
  const [sessions, setSessions] = useState<Session[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  const fetchSessions = async () => {
    try {
      setLoading(true);
      const now = new Date().toISOString();
      // Show sessions starting in the next 7 days
      const sevenDaysLater = new Date(Date.now() + 7 * 24 * 60 * 60 * 1000).toISOString();

      const { data: sessionsData, error } = await supabase
        .from('sessions')
        .select('*')
        .eq('is_open', true)
        .gte('starts_at', now)
        .lte('starts_at', sevenDaysLater)
        .order('starts_at', { ascending: true })
        .limit(20);

      if (error) throw error;

      // For each session, count members
      const sessionsWithSpots = await Promise.all(
        (sessionsData || []).map(async (session) => {
          const { count } = await supabase
            .from('session_members')
            .select('*', { count: 'exact', head: true })
            .eq('session_id', session.id)
            .eq('status', 'joined');

          return {
            ...session,
            spots_left: Math.max(0, session.capacity - (count || 0)),
          };
        })
      );

      setSessions(sessionsWithSpots);
    } catch (err: any) {
      setError(err.message);
      console.error('Error fetching sessions:', err);
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    fetchSessions();
  }, []);

  return { sessions, loading, error, refetch: fetchSessions };
}
