import { View, Text, ScrollView, StyleSheet, Pressable, RefreshControl, ActivityIndicator } from 'react-native';
import { useState } from 'react';
import { useRouter } from 'expo-router';
import { useFeed } from '../hooks/useFeed';
import { useSession } from '../hooks/useSession';
import { makeTitle } from '../lib/title';

export default function Main() {
  const { session } = useSession();
  const { sessions, loading, error, refetch } = useFeed();
  const router = useRouter();
  const [refreshing, setRefreshing] = useState(false);

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
        <Text style={styles.headerTitle}>PickUp UCF</Text>
        <Pressable onPress={() => router.push('/create')}>
          <Text style={styles.createButton}>+ Create</Text>
        </Pressable>
      </View>

      <ScrollView
        style={styles.scroll}
        refreshControl={<RefreshControl refreshing={refreshing} onRefresh={onRefresh} />}
      >
        {sessions.length === 0 ? (
          <View style={styles.emptyState}>
            <Text style={styles.emptyTitle}>No sessions yet</Text>
            <Text style={styles.emptySubtitle}>Create the first one!</Text>
            <Pressable onPress={() => router.push('/create')} style={styles.createFirstButton}>
              <Text style={styles.createFirstText}>+ Create Session</Text>
            </Pressable>
          </View>
        ) : (
          <View style={styles.list}>
            {sessions.map((session) => (
              <Pressable
                key={session.id}
                style={styles.card}
                onPress={() => router.push(`/session/${session.id}`)}
              >
                <Text style={styles.cardTitle}>
                  {makeTitle({
                    sport: session.sport,
                    custom_sport: session.custom_sport,
                    address: session.address,
                    starts_at: session.starts_at,
                    ends_at: session.ends_at,
                    capacity: session.capacity,
                    equipment_needed: session.equipment_needed,
                    positions: session.positions,
                  })}
                </Text>
                {session.notes && <Text style={styles.cardNotes}>{session.notes}</Text>}
                <View style={styles.cardFooter}>
                  <Text style={styles.cardSpots}>
                    {session.spots_left ?? 0} spots left
                  </Text>
                  <View style={styles.badgeRow}>
                    {session.skill_target !== 'Any' && (
                      <View style={[styles.badge, styles.skillBadge]}>
                        <Text style={styles.badgeText}>{session.skill_target}</Text>
                      </View>
                    )}
                    {session.is_indoor && (
                      <View style={[styles.badge, styles.typeBadge]}>
                        <Text style={styles.badgeText}>Indoor</Text>
                      </View>
                    )}
                  </View>
                </View>
              </Pressable>
            ))}
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
  headerTitle: { fontSize: 24, fontWeight: '800', color: '#007AFF' },
  createButton: { fontSize: 16, fontWeight: '600', color: '#007AFF' },
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
  cardTitle: { fontSize: 16, fontWeight: '600', marginBottom: 8, color: '#333' },
  cardNotes: { fontSize: 14, color: '#666', marginBottom: 12 },
  cardFooter: { flexDirection: 'row', justifyContent: 'space-between', alignItems: 'center' },
  cardSpots: { fontSize: 14, fontWeight: '600', color: '#007AFF' },
  badgeRow: { flexDirection: 'row', gap: 6 },
  badge: { paddingHorizontal: 8, paddingVertical: 4, borderRadius: 4 },
  skillBadge: { backgroundColor: '#FFE5B4' },
  typeBadge: { backgroundColor: '#E3F2FD' },
  badgeText: { fontSize: 12, fontWeight: '600', color: '#333' },
  emptyState: { alignItems: 'center', marginTop: 60, padding: 32 },
  emptyTitle: { fontSize: 20, fontWeight: '700', marginBottom: 8 },
  emptySubtitle: { fontSize: 14, color: '#666', marginBottom: 24 },
  createFirstButton: { backgroundColor: '#007AFF', paddingHorizontal: 24, paddingVertical: 12, borderRadius: 8 },
  createFirstText: { color: 'white', fontWeight: '600' },
  errorText: { color: '#FF3B30', marginBottom: 16 },
  retryButton: { backgroundColor: '#007AFF', paddingHorizontal: 16, paddingVertical: 8, borderRadius: 8 },
  retryText: { color: 'white', fontWeight: '600' },
});
