import { ExpoConfig } from 'expo/config';

export default (): ExpoConfig => ({
  name: 'PickUp UCF',
  slug: 'pickup-ucf',
  scheme: 'pickupucf',
  version: '0.1.0',
  orientation: 'portrait',
  ios: { bundleIdentifier: 'com.yourname.pickupucf' },
  android: { package: 'com.yourname.pickupucf' },
  plugins: ['expo-router', 'expo-notifications', 'expo-location'],
  extra: {
    supabaseUrl: process.env.EXPO_PUBLIC_SUPABASE_URL,
    supabaseAnonKey: process.env.EXPO_PUBLIC_SUPABASE_ANON_KEY,
    env: process.env.EXPO_PUBLIC_ENV ?? 'dev',
  },
});
