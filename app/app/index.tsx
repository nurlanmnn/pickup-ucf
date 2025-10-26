import { Redirect } from 'expo-router';
import { useSession } from '../hooks/useSession';

export default function Index() {
  const { session, loading } = useSession();

  if (loading) return null;
  
  if (!session) return <Redirect href="/(auth)/signin" />;
  
  return <Redirect href="/main" />;
}
