import { useEffect } from 'react';
import { View, Text, ActivityIndicator } from 'react-native';
import { Redirect, useLocalSearchParams } from 'expo-router';
import { useSession } from '../hooks/useSession';
import { supabase } from '../lib/supabase';

export default function AuthCallback() {
  const { session } = useSession();
  const params = useLocalSearchParams();

  useEffect(() => {
    async function handleAuth() {
      // Check if we have URL parameters (from deep link)
      const access_token = params.access_token as string;
      const refresh_token = params.refresh_token as string;
      
      if (access_token && refresh_token) {
        try {
          // Set the session with the tokens
          const { data, error } = await supabase.auth.setSession({
            access_token,
            refresh_token,
          });
          
          if (error) {
            console.error('Auth error:', error);
          } else {
            console.log('Auth successful:', data);
          }
        } catch (error) {
          console.error('Auth callback error:', error);
        }
      }
    }
    
    handleAuth();
  }, [params]);

  // If session exists, redirect to feed
  if (session) {
    return <Redirect href="/(tabs)/feed" />;
  }

  return (
    <View style={{ flex: 1, justifyContent: 'center', alignItems: 'center', gap: 12 }}>
      <ActivityIndicator size="large" />
      <Text style={{ fontSize: 16, color: '#666' }}>Signing you in…</Text>
    </View>
  );
}
