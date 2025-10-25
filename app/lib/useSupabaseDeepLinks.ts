import { useEffect } from 'react';
import * as Linking from 'expo-linking';

export function useSupabaseDeepLinks() {
  useEffect(() => {
    // Handle initial URL
    Linking.getInitialURL().then((url) => {
      if (url) {
        console.log('Initial URL:', url);
      }
    });

    // Listen for URL events
    const subscription = Linking.addEventListener('url', ({ url }) => {
      console.log('URL event:', url);
    });

    return () => {
      subscription.remove();
    };
  }, []);
}
