import { useEffect, useState, useCallback } from 'react';
import { supabase } from '../lib/supabase';

export function useSession() {
  const [session, setSession] = useState<any>(null);
  const [loading, setLoading] = useState(true);

  const fetchSession = useCallback(async () => {
    const { data } = await supabase.auth.getSession();
    setSession(data.session ?? null);
    setLoading(false);
  }, []);

  useEffect(() => {
    fetchSession();
    const { data: sub } = supabase.auth.onAuthStateChange((_e, s) => setSession(s));
    return () => sub.subscription.unsubscribe();
  }, [fetchSession]);

  return { session, loading, refresh: fetchSession };
}
