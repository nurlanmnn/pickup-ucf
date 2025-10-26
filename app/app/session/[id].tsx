import { useState, useEffect, useCallback } from 'react';
import { View, Text, ScrollView, Pressable, StyleSheet, Alert, ActivityIndicator } from 'react-native';
import { useLocalSearchParams, useRouter, useFocusEffect } from 'expo-router';
import { supabase } from '../../lib/supabase';
import { useSession } from '../../hooks/useSession';
import { makeTitle } from '../../lib/title';

const getSkillName = (code: string): string => {
  switch (code) {
    case 'B': return 'Beginner';
    case 'I': return 'Intermediate';
    case 'A': return 'Advanced';
    case 'Any': return 'Any';
    default: return code;
  }
};

export default function SessionDetail() {
  const { id } = useLocalSearchParams<{ id: string }>();
  const { session: authSession, loading: authLoading } = useSession();
  const router = useRouter();
  const [loading, setLoading] = useState(true);
  const [joining, setJoining] = useState(false);
  const [leaving, setLeaving] = useState(false);
  const [sessionData, setSessionData] = useState<any>(null);
  const [isJoined, setIsJoined] = useState(false);
  const [membersCount, setMembersCount] = useState(0);
  const [members, setMembers] = useState<any[]>([]);
  const [userProfile, setUserProfile] = useState<any>(null);

  useEffect(() => {
    if (id && !authLoading) {
      fetchSession();
      fetchUserProfile();
    }
  }, [id, authSession]);

  const fetchUserProfile = async () => {
    if (!authSession?.user) return;
    const { data } = await supabase
      .from('profiles')
      .select('name')
      .eq('id', authSession.user.id)
      .single();
    setUserProfile(data);
  };

  const fetchSession = async () => {
    try {
      const { data, error } = await supabase
        .from('sessions')
        .select(`
          *,
          host:profiles!sessions_host_id_fkey(id, email, name)
        `)
        .eq('id', id)
        .single();

      if (error) throw error;

      setSessionData(data);
      
      // Check if current user is already a member
      if (authSession?.user) {
        const { data: memberData, error: memberError } = await supabase
          .from('session_members')
          .select('status')
          .eq('session_id', id)
          .eq('user_id', authSession.user.id)
          .maybeSingle();

        // User is joined if the record exists and has status 'joined'
        const joined = !!memberData && memberData.status === 'joined';
        setIsJoined(joined);
      }
      
      // Fetch all members with their profiles
      const { data: membersData } = await supabase
        .from('session_members')
        .select(`
          user_id,
          status,
          joined_at,
          profiles(id, name, email)
        `)
        .eq('session_id', id)
        .eq('status', 'joined')
        .order('joined_at', { ascending: true });

      setMembers(membersData || []);
      setMembersCount(membersData?.length || 0);
    } catch (err: any) {
      Alert.alert('Error', err.message);
    } finally {
      setLoading(false);
    }
  };

  // Refresh when screen is focused
  useFocusEffect(
    useCallback(() => {
      if (id && !authLoading) {
        fetchSession();
        fetchUserProfile();
      }
    }, [id, authSession])
  );

  const handleJoin = async () => {
    if (!authSession?.user) {
      Alert.alert('Error', 'You must be logged in to join a session');
      return;
    }

    // Check if profile is complete by fetching fresh data
    const { data: profileData } = await supabase
      .from('profiles')
      .select('name')
      .eq('id', authSession.user.id)
      .single();

    if (!profileData?.name) {
      Alert.alert(
        'Complete Your Profile',
        'You need to complete your profile before joining sessions. Please add your name.',
        [
          { text: 'Cancel', style: 'cancel' },
          { text: 'Go to Profile', onPress: () => router.push('/profile-setup') }
        ]
      );
      return;
    }

    setJoining(true);

    try {
      // Check if user is already a member
      const { data: existingMember } = await supabase
        .from('session_members')
        .select('status')
        .eq('session_id', id)
        .eq('user_id', authSession.user.id)
        .maybeSingle();

      if (existingMember && existingMember.status === 'joined') {
        Alert.alert('Already Joined', 'You are already a member of this session.');
        setJoining(false);
        return;
      }

      // If member exists with different status, update it
      if (existingMember) {
        const { error } = await supabase
          .from('session_members')
          .update({ status: 'joined' })
          .eq('session_id', id)
          .eq('user_id', authSession.user.id);
        
        if (error) throw error;
      } else {
        // Insert new member
        const { error } = await supabase
          .from('session_members')
          .insert({
            session_id: id,
            user_id: authSession.user.id,
            status: 'joined',
          });
        
        if (error) throw error;
      }

      // Refresh to get updated member list
      await fetchSession();
      
      // Force set isJoined to true
      setIsJoined(true);
      
      Alert.alert('Success', 'You joined this session!');
    } catch (err: any) {
      // Handle duplicate key error gracefully
      if (err.message?.includes('duplicate key')) {
        Alert.alert('Already Joined', 'You are already a member of this session.');
        await fetchSession();
      } else {
        Alert.alert('Error', err.message);
      }
    } finally {
      setJoining(false);
    }
  };

  const handleLeave = async () => {
    if (!authSession?.user) {
      Alert.alert('Error', 'You must be logged in');
      return;
    }

    setLeaving(true);

    try {
      const { error } = await supabase
        .from('session_members')
        .delete()
        .eq('session_id', id)
        .eq('user_id', authSession.user.id);

      if (error) throw error;

      // Refresh to get updated member list
      await fetchSession();
      
      // Force set isJoined to false
      setIsJoined(false);
      
      Alert.alert('Success', 'You left this session');
    } catch (err: any) {
      Alert.alert('Error', err.message);
    } finally {
      setLeaving(false);
    }
  };

  const handleDelete = async () => {
    Alert.alert(
      'Delete Session',
      'Are you sure you want to delete this session?',
      [
        { text: 'Cancel', style: 'cancel' },
        { 
          text: 'Delete', 
          style: 'destructive',
          onPress: async () => {
            try {
              const { error } = await supabase
                .from('sessions')
                .delete()
                .eq('id', id)
                .eq('host_id', authSession?.user?.id);

              if (error) throw error;

              Alert.alert('Success', 'Session deleted');
              router.back();
            } catch (err: any) {
              Alert.alert('Error', err.message);
            }
          }
        }
      ]
    );
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
  const isHost = sessionData.host_id === authSession?.user?.id;

  return (
    <View style={styles.container}>
      <View style={styles.header}>
        <Pressable onPress={() => router.back()} style={styles.backButton} hitSlop={{ top: 10, bottom: 10, left: 10, right: 10 }}>
          <Text style={styles.backText}>← Back</Text>
        </Pressable>
        <Text style={styles.headerTitle}>Session Details</Text>
        <View style={{ width: 60 }} />
      </View>
      <ScrollView style={styles.scroll}>

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
              Skill level: {getSkillName(sessionData.skill_target)}
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
            {sessionData.host?.name || sessionData.host?.email || 'Unknown'}
          </Text>
        </View>

        <View style={styles.section}>
          <Text style={styles.sectionTitle}>
            Members ({membersCount}/{sessionData.capacity})
          </Text>
          {members.length === 0 ? (
            <Text style={styles.emptyText}>No one has joined yet</Text>
          ) : (
            members.map((member) => (
              <View key={member.user_id} style={styles.memberRow}>
                <View style={styles.memberAvatar}>
                  <Text style={styles.memberInitial}>
                    {member.profiles?.name?.charAt(0).toUpperCase() || '?'}
                  </Text>
                </View>
                <View style={styles.memberInfo}>
                  <Text style={styles.memberName}>
                    {member.profiles?.name || 'Unknown'}
                    {member.user_id === sessionData.host_id && ' 👑'}
                  </Text>
                  <Text style={styles.memberEmail}>{member.profiles?.email}</Text>
                </View>
              </View>
            ))
          )}
        </View>

        <View style={styles.buttonContainer}>
          {isHost ? (
            <>
              <Pressable
                style={[styles.joinButton, styles.editButton]}
                onPress={() => Alert.alert(
                  'Edit Session', 
                  'To edit your session, you can:\n\n1. Delete this session\n2. Create a new one with updated details\n\nFull edit feature coming soon!', 
                  [{ text: 'OK' }]
                )}
              >
                <Text style={styles.joinText}>Edit Session</Text>
              </Pressable>
              <View style={{ height: 12 }} />
              <Pressable
                style={[styles.joinButton, styles.deleteButton]}
                onPress={handleDelete}
              >
                <Text style={styles.joinText}>Delete Session</Text>
              </Pressable>
            </>
          ) : isJoined ? (
            <Pressable
              style={[styles.joinButton, styles.leaveButton, (leaving || joining) && styles.buttonDisabled]}
              onPress={handleLeave}
              disabled={leaving || joining}
            >
              {leaving ? (
                <ActivityIndicator color="white" />
              ) : (
                <Text style={styles.joinText}>Leave Session</Text>
              )}
            </Pressable>
          ) : (
            <Pressable
              style={[styles.joinButton, (joining || leaving) && styles.buttonDisabled]}
              onPress={handleJoin}
              disabled={joining || leaving || spotsLeft <= 0}
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
    </View>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1, backgroundColor: '#F5F5F5' },
  center: { flex: 1, justifyContent: 'center', alignItems: 'center' },
  header: { 
    flexDirection: 'row', 
    alignItems: 'center', 
    justifyContent: 'space-between',
    paddingHorizontal: 16, 
    paddingVertical: 12, 
    paddingTop: 60,
    backgroundColor: 'white', 
    borderBottomWidth: 1, 
    borderBottomColor: '#E0E0E0' 
  },
  backButton: { paddingVertical: 8, paddingRight: 16 },
  backText: { fontSize: 16, color: '#007AFF', fontWeight: '600' },
  headerTitle: { fontSize: 18, fontWeight: '700', color: '#333', flex: 1 },
  scroll: { flex: 1 },
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
  editButton: { backgroundColor: '#34C759' },
  leaveButton: { backgroundColor: '#FF3B30' },
  deleteButton: { backgroundColor: '#FF3B30' },
  buttonDisabled: { opacity: 0.5 },
  joinText: { color: 'white', fontSize: 16, fontWeight: '600' },
  errorText: { color: '#FF3B30', fontSize: 16 },
  emptyText: { fontSize: 14, color: '#999', fontStyle: 'italic' },
  memberRow: { flexDirection: 'row', alignItems: 'center', marginTop: 12 },
  memberAvatar: { width: 40, height: 40, borderRadius: 20, backgroundColor: '#007AFF', justifyContent: 'center', alignItems: 'center', marginRight: 12 },
  memberInitial: { color: 'white', fontSize: 16, fontWeight: '700' },
  memberInfo: { flex: 1 },
  memberName: { fontSize: 14, fontWeight: '600', color: '#333', marginBottom: 2 },
  memberEmail: { fontSize: 12, color: '#999' },
});
