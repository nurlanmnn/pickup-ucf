import { useState, useEffect } from 'react';
import { View, Text, ScrollView, Pressable, StyleSheet, Alert, ActivityIndicator } from 'react-native';
import { useLocalSearchParams, useRouter } from 'expo-router';
import { supabase } from '../../lib/supabase';
import { useSession } from '../../hooks/useSession';
import { makeTitle } from '../../lib/title';

export default function SessionDetail() {
  const { id } = useLocalSearchParams<{ id: string }>();
  const { session: authSession } = useSession();
  const router = useRouter();
  const [loading, setLoading] = useState(true);
  const [joining, setJoining] = useState(false);
  const [sessionData, setSessionData] = useState<any>(null);
  const [isJoined, setIsJoined] = useState(false);
  const [membersCount, setMembersCount] = useState(0);

  useEffect(() => {
    if (id) fetchSession();
  }, [id]);

  const fetchSession = async () => {
    try {
      const { data, error } = await supabase
        .from('sessions')
        .select(`
          *,
          profiles(id, email, name),
          session_members(count, user_id)
        `)
        .eq('id', id)
        .single();

      if (error) throw error;

      setSessionData(data);
      
      // Check if current user is already a member
      const { data: memberData } = await supabase
        .from('session_members')
        .select('status')
        .eq('session_id', id)
        .eq('user_id', authSession?.user?.id)
        .single();

      setIsJoined(memberData?.status === 'joined');
      
      // Count joined members
      const { count } = await supabase
        .from('session_members')
        .select('*', { count: 'exact', head: true })
        .eq('session_id', id)
        .eq('status', 'joined');
      
      setMembersCount(count || 0);
    } catch (err: any) {
      Alert.alert('Error', err.message);
    } finally {
      setLoading(false);
    }
  };

  const handleJoin = async () => {
    if (!authSession?.user) {
      Alert.alert('Error', 'You must be logged in to join a session');
      return;
    }

    setJoining(true);

    try {
      const { error } = await supabase
        .from('session_members')
        .insert({
          session_id: id,
          user_id: authSession.user.id,
          status: 'joined',
        });

      if (error) throw error;

      setIsJoined(true);
      setMembersCount(m => m + 1);
      Alert.alert('Success', 'You joined this session!');
    } catch (err: any) {
      Alert.alert('Error', err.message);
    } finally {
      setJoining(false);
    }
  };

  if (loading) {
    return (
      <View style={styles.center}>
        <ActivityIndicator size="large" color="#007AFF" />
      </View>
    );
  }

  if (!sessionData) {
    return (
      <View style={styles.center}>
        <Text style={styles.errorText}>Session not found</Text>
      </View>
    );
  }

  const spotsLeft = sessionData.capacity - membersCount;

  return (
    <ScrollView style={styles.container}>
      <View style={styles.header}>
        <Pressable onPress={() => router.back()} style={styles.backButton}>
          <Text style={styles.backText}>← Back</Text>
        </Pressable>
      </View>

      <View style={styles.content}>
        <Text style={styles.title}>
          {makeTitle({
            sport: sessionData.sport,
            custom_sport: sessionData.custom_sport,
            address: sessionData.address,
            starts_at: sessionData.starts_at,
            ends_at: sessionData.ends_at,
            capacity: sessionData.capacity,
            equipment_needed: sessionData.equipment_needed,
            positions: sessionData.positions,
          })}
        </Text>

        {sessionData.notes && (
          <View style={styles.section}>
            <Text style={styles.sectionTitle}>Details</Text>
            <Text style={styles.sectionText}>{sessionData.notes}</Text>
          </View>
        )}

        <View style={styles.section}>
          <Text style={styles.sectionTitle}>When</Text>
          <Text style={styles.sectionText}>
            {new Date(sessionData.starts_at).toLocaleDateString('en-US', {
              weekday: 'long',
              month: 'long',
              day: 'numeric',
            })}
            {' '}
            {new Date(sessionData.starts_at).toLocaleTimeString('en-US', {
              hour: 'numeric',
              minute: '2-digit',
            })}
            {' - '}
            {new Date(sessionData.ends_at).toLocaleTimeString('en-US', {
              hour: 'numeric',
              minute: '2-digit',
            })}
          </Text>
        </View>

        {sessionData.address && (
          <View style={styles.section}>
            <Text style={styles.sectionTitle}>Location</Text>
            <Text style={styles.sectionText}>{sessionData.address}</Text>
          </View>
        )}

        <View style={styles.section}>
          <Text style={styles.sectionTitle}>Info</Text>
          <Text style={styles.sectionText}>
            Capacity: {sessionData.capacity} players
          </Text>
          <Text style={styles.sectionText}>
            {spotsLeft} spots left
          </Text>
          {sessionData.skill_target !== 'Any' && (
            <Text style={styles.sectionText}>
              Skill level: {sessionData.skill_target}
            </Text>
          )}
          {sessionData.is_indoor && (
            <Text style={styles.sectionText}>📍 Indoor</Text>
          )}
          {sessionData.equipment_needed && (
            <Text style={styles.sectionText}>⚽ Equipment needed</Text>
          )}
        </View>

        {sessionData.positions && sessionData.positions.length > 0 && (
          <View style={styles.section}>
            <Text style={styles.sectionTitle}>Positions Needed</Text>
            <View style={styles.chipContainer}>
              {sessionData.positions.map((pos: string) => (
                <View key={pos} style={styles.chip}>
                  <Text style={styles.chipText}>{pos}</Text>
                </View>
              ))}
            </View>
          </View>
        )}

        <View style={styles.section}>
          <Text style={styles.sectionTitle}>Host</Text>
          <Text style={styles.sectionText}>
            {sessionData.profiles?.name || sessionData.profiles?.email || 'Unknown'}
          </Text>
        </View>

        <View style={styles.buttonContainer}>
          {isJoined ? (
            <Pressable style={[styles.joinButton, styles.joinedButton]} disabled>
              <Text style={styles.joinText}>✓ Joined</Text>
            </Pressable>
          ) : (
            <Pressable
              style={[styles.joinButton, joining && styles.buttonDisabled]}
              onPress={handleJoin}
              disabled={joining || spotsLeft <= 0}
            >
              {joining ? (
                <ActivityIndicator color="white" />
              ) : (
                <Text style={styles.joinText}>
                  {spotsLeft > 0 ? 'Join Session' : 'Full'}
                </Text>
              )}
            </Pressable>
          )}
        </View>
      </View>
    </ScrollView>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1, backgroundColor: '#F5F5F5' },
  center: { flex: 1, justifyContent: 'center', alignItems: 'center' },
  header: { padding: 16, backgroundColor: 'white', borderBottomWidth: 1, borderBottomColor: '#E0E0E0' },
  backButton: { paddingVertical: 8 },
  backText: { fontSize: 16, color: '#007AFF', fontWeight: '600' },
  content: { padding: 16 },
  title: { fontSize: 20, fontWeight: '700', marginBottom: 24, color: '#333' },
  section: { backgroundColor: 'white', padding: 16, borderRadius: 12, marginBottom: 12 },
  sectionTitle: { fontSize: 16, fontWeight: '700', marginBottom: 8, color: '#007AFF' },
  sectionText: { fontSize: 14, color: '#666', lineHeight: 20 },
  chipContainer: { flexDirection: 'row', flexWrap: 'wrap', gap: 8 },
  chip: { backgroundColor: '#E3F2FD', paddingHorizontal: 12, paddingVertical: 6, borderRadius: 16 },
  chipText: { fontSize: 12, fontWeight: '600', color: '#007AFF' },
  buttonContainer: { padding: 16 },
  joinButton: { backgroundColor: '#007AFF', padding: 16, borderRadius: 12, alignItems: 'center' },
  joinedButton: { backgroundColor: '#34C759' },
  buttonDisabled: { opacity: 0.5 },
  joinText: { color: 'white', fontSize: 16, fontWeight: '600' },
  errorText: { color: '#FF3B30', fontSize: 16 },
});
