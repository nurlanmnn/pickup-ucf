import { View, Text, ScrollView, StyleSheet, Pressable, RefreshControl, ActivityIndicator, TextInput } from 'react-native';
import { useState, useEffect, useMemo } from 'react';
import { useRouter } from 'expo-router';
import { useFeed } from '../hooks/useFeed';
import { useSession } from '../hooks/useSession';
import { makeTitle } from '../lib/title';
import { supabase } from '../lib/supabase';

const getSkillName = (code: string): string => {
  switch (code) {
    case 'B': return 'Beginner';
    case 'I': return 'Intermediate';
    case 'A': return 'Advanced';
    case 'Any': return 'Any';
    default: return code;
  }
};

export default function Main() {
  const { session } = useSession();
  const { sessions, loading, error, refetch } = useFeed();
  const router = useRouter();
  const [refreshing, setRefreshing] = useState(false);
  const [userName, setUserName] = useState('');
  const [searchQuery, setSearchQuery] = useState('');

  // Filter sessions based on search query
  const filteredSessions = useMemo(() => {
    if (!searchQuery.trim()) {
      return sessions;
    }

    const query = searchQuery.toLowerCase().trim();
    return sessions.filter((sessionItem) => {
      // Get sport name for matching
      const sportName = (sessionItem.sport || '').toLowerCase();
      const customSportName = (sessionItem.custom_sport || '').toLowerCase();
      
      // Check if sport name contains the search query
      return sportName.includes(query) || customSportName.includes(query);
    });
  }, [sessions, searchQuery]);

  useEffect(() => {
    if (session?.user) {
      supabase
        .from('profiles')
        .select('name, email')
        .eq('id', session.user.id)
        .single()
        .then(({ data }) => {
          if (data) {
            // If name is missing or empty but email exists, auto-generate from email
            if ((!data.name || data.name.trim() === '') && data.email) {
              const autoName = data.email.split('@')[0];
              supabase
                .from('profiles')
                .update({ name: autoName })
                .eq('id', session.user.id)
                .then(() => setUserName(autoName));
            } else if (data.name) {
              setUserName(data.name);
            }
          }
        });
    }
  }, [session]);

  const onRefresh = async () => {
    setRefreshing(true);
    await refetch();
    setRefreshing(false);
  };

  if (loading) {
    return (
      <View style={styles.center}>
        <ActivityIndicator size="large" color="#007AFF" />
      </View>
    );
  }

  if (error) {
    return (
      <View style={styles.center}>
        <Text style={styles.errorText}>Error: {error}</Text>
        <Pressable onPress={refetch} style={styles.retryButton}>
          <Text style={styles.retryText}>Retry</Text>
        </Pressable>
      </View>
    );
  }

  return (
    <View style={styles.container}>
      <View style={styles.header}>
        <Pressable onPress={() => router.push('/profile')} style={styles.profileButton}>
          <View style={styles.profileAvatar}>
            <Text style={styles.profileInitial}>
              {userName?.charAt(0).toUpperCase() || '?'}
            </Text>
          </View>
        </Pressable>
        <Text style={styles.headerTitle}>PickUp UCF</Text>
        <Pressable onPress={() => router.push('/create')}>
          <Text style={styles.createButton}>+ Create</Text>
        </Pressable>
      </View>

      {/* Search Bar */}
      <View style={styles.searchContainer}>
        <TextInput
          style={styles.searchInput}
          placeholder="Search sports (e.g., football, tennis)"
          value={searchQuery}
          onChangeText={setSearchQuery}
          placeholderTextColor="#999"
        />
        {searchQuery.length > 0 && (
          <Pressable onPress={() => setSearchQuery('')} style={styles.clearButton}>
            <Text style={styles.clearButtonText}>✕</Text>
          </Pressable>
        )}
      </View>

      <ScrollView
        style={styles.scroll}
        refreshControl={<RefreshControl refreshing={refreshing} onRefresh={onRefresh} />}
      >
        {filteredSessions.length === 0 ? (
          <View style={styles.emptyState}>
            {searchQuery ? (
              <>
                <Text style={styles.emptyTitle}>No matching sessions</Text>
                <Text style={styles.emptySubtitle}>Try a different search term</Text>
              </>
            ) : (
              <>
                <Text style={styles.emptyTitle}>No sessions yet</Text>
                <Text style={styles.emptySubtitle}>Create the first one!</Text>
                <Pressable onPress={() => router.push('/create')} style={styles.createFirstButton}>
                  <Text style={styles.createFirstText}>+ Create Session</Text>
                </Pressable>
              </>
            )}
          </View>
        ) : (
          <View style={styles.list}>
            {filteredSessions.map((sessionItem) => {
              const isHost = sessionItem.host_id === session?.user?.id;
              return (
              <Pressable
                key={sessionItem.id}
                style={styles.card}
                onPress={() => router.push(`/session/${sessionItem.id}`)}
              >
                <View style={styles.cardHeader}>
                  <Text style={styles.cardTitle}>
                    {makeTitle({
                      sport: sessionItem.sport,
                      custom_sport: sessionItem.custom_sport,
                      address: sessionItem.address,
                      starts_at: sessionItem.starts_at,
                      ends_at: sessionItem.ends_at,
                      // capacity: sessionItem.capacity,
                      // equipment_needed: sessionItem.equipment_needed,
                      // positions: sessionItem.positions,
                    })}
                  </Text>
                  {isHost && (
                    <View style={styles.hostBadge}>
                      <Text style={styles.hostBadgeText}>👑 Your Session</Text>
                    </View>
                  )}
                </View>
                {sessionItem.notes && <Text style={styles.cardNotes}>{sessionItem.notes}</Text>}
                <View style={styles.cardFooter}>
                  <Text style={styles.cardSpots}>
                    {sessionItem.spots_left ?? 0} spots left
                  </Text>
                  <View style={styles.badgeRow}>
                    {sessionItem.skill_target !== 'Any' && (
                      <View style={[styles.badge, styles.skillBadge]}>
                        <Text style={styles.badgeText}>{getSkillName(sessionItem.skill_target)}</Text>
                      </View>
                    )}
                    {sessionItem.is_indoor && (
                      <View style={[styles.badge, styles.typeBadge]}>
                        <Text style={styles.badgeText}>Indoor</Text>
                      </View>
                    )}
                  </View>
                </View>
              </Pressable>
            );
            })}
          </View>
        )}
      </ScrollView>
    </View>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1, backgroundColor: '#F5F5F5' },
  center: { flex: 1, justifyContent: 'center', alignItems: 'center' },
  header: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    padding: 16,
    paddingTop: 60,
    backgroundColor: 'white',
    borderBottomWidth: 1,
    borderBottomColor: '#E0E0E0',
  },
  searchContainer: {
    backgroundColor: 'white',
    padding: 16,
    flexDirection: 'row',
    alignItems: 'center',
    borderBottomWidth: 1,
    borderBottomColor: '#E0E0E0',
  },
  searchInput: {
    flex: 1,
    backgroundColor: '#F5F5F5',
    paddingHorizontal: 16,
    paddingVertical: 12,
    borderRadius: 10,
    fontSize: 16,
    borderWidth: 1,
    borderColor: '#E0E0E0',
  },
  clearButton: {
    marginLeft: 8,
    width: 32,
    height: 32,
    justifyContent: 'center',
    alignItems: 'center',
  },
  clearButtonText: {
    fontSize: 18,
    color: '#666',
    fontWeight: '600',
  },
  profileButton: { marginRight: 8 },
  profileAvatar: {
    width: 36,
    height: 36,
    borderRadius: 18,
    backgroundColor: '#FFC904', // UCF Gold
    justifyContent: 'center',
    alignItems: 'center',
  },
  profileInitial: { fontSize: 16, fontWeight: '700', color: '#000000' },
  headerTitle: { fontSize: 24, fontWeight: '800', color: '#000000', flex: 1, textAlign: 'center' },
  createButton: { fontSize: 16, fontWeight: '600', color: '#FFC904' },
  scroll: { flex: 1 },
  list: { padding: 16, gap: 12 },
  card: {
    backgroundColor: 'white',
    borderRadius: 12,
    padding: 16,
    marginBottom: 12,
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 2 },
    shadowOpacity: 0.1,
    shadowRadius: 4,
    elevation: 3,
  },
  cardHeader: { flexDirection: 'row', justifyContent: 'space-between', alignItems: 'flex-start', marginBottom: 4 },
  cardTitle: { fontSize: 16, fontWeight: '600', flex: 1, marginBottom: 8, color: '#333' },
  hostBadge: { 
    backgroundColor: '#FFC904', 
    paddingHorizontal: 10, 
    paddingVertical: 4, 
    borderRadius: 12, 
    marginLeft: 8,
    marginTop: -2,
  },
  hostBadgeText: { fontSize: 11, fontWeight: '700', color: '#000000' },
  cardNotes: { fontSize: 14, color: '#666', marginBottom: 12 },
  cardFooter: { flexDirection: 'row', justifyContent: 'space-between', alignItems: 'center' },
  cardSpots: { fontSize: 14, fontWeight: '600', color: '#FFC904' },
  badgeRow: { flexDirection: 'row', gap: 6 },
  badge: { paddingHorizontal: 8, paddingVertical: 4, borderRadius: 4 },
  skillBadge: { backgroundColor: '#FFF4D6' },
  typeBadge: { backgroundColor: '#FFFCE8' },
  badgeText: { fontSize: 12, fontWeight: '600', color: '#333' },
  emptyState: { alignItems: 'center', marginTop: 60, padding: 32 },
  emptyTitle: { fontSize: 20, fontWeight: '700', marginBottom: 8 },
  emptySubtitle: { fontSize: 14, color: '#666', marginBottom: 24 },
  createFirstButton: { backgroundColor: '#FFC904', paddingHorizontal: 24, paddingVertical: 12, borderRadius: 8 },
  createFirstText: { color: '#000000', fontWeight: '600' },
  errorText: { color: '#FF3B30', marginBottom: 16 },
  retryButton: { backgroundColor: '#FFC904', paddingHorizontal: 16, paddingVertical: 8, borderRadius: 8 },
  retryText: { color: '#000000', fontWeight: '600' },
});
