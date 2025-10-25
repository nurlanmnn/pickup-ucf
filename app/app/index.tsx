import { Redirect } from 'expo-router';
import { useSession } from '../hooks/useSession';
import { useState, useEffect } from 'react';
import { supabase } from '../lib/supabase';

export default function Index() {
  const { session, loading } = useSession();
  const [needsProfile, setNeedsProfile] = useState<boolean | null>(null);

  useEffect(() => {
    if (session?.user) {
      checkProfile();
    } else {
      setNeedsProfile(false); // Will redirect to signin
    }
  }, [session]);

  const checkProfile = async () => {
    const { data } = await supabase
      .from('profiles')
      .select('name')
      .eq('id', session?.user?.id)
      .single();
    
    // If no data or no name, need profile setup
    setNeedsProfile(!data || !data.name);
  };

  if (loading || needsProfile === null) return null;
  
  if (!session) return <Redirect href="/(auth)/signin" />;
  
  if (needsProfile) {
    return <Redirect href="/profile-setup" />;
  }
  
  return <Redirect href="/main" />;
}
