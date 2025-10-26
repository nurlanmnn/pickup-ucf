import { useState, useEffect } from 'react';
import { View, Text, Pressable, StyleSheet, Alert, ActivityIndicator, TextInput } from 'react-native';
import { useRouter } from 'expo-router';
import { supabase } from '../lib/supabase';
import { useSession } from '../hooks/useSession';

export default function Profile() {
  const { session, refresh } = useSession();
  const router = useRouter();
  const [profile, setProfile] = useState<any>(null);
  const [loading, setLoading] = useState(true);
  const [loggingOut, setLoggingOut] = useState(false);
  const [editing, setEditing] = useState(false);
  const [name, setName] = useState('');
  const [saving, setSaving] = useState(false);

  useEffect(() => {
    if (session?.user) {
      fetchProfile();
    }
  }, [session]);

  const fetchProfile = async () => {
    if (!session?.user) return;
    
    const { data, error } = await supabase
      .from('profiles')
      .select('*')
      .eq('id', session.user.id)
      .maybeSingle();

    if (error && error.code !== 'PGRST116') {
      setLoading(false);
      return;
    }

    // If no profile exists, create it
    if (!data) {
      const autoName = session.user.email?.split('@')[0] || 'User';
      const { data: newProfile } = await supabase
        .from('profiles')
        .insert({
          id: session.user.id,
          email: session.user.email,
          name: autoName,
        })
        .select()
        .single();
      
      if (newProfile) {
        setProfile(newProfile);
      }
      setLoading(false);
      return;
    }

    // Ensure name is not empty or "User"
    let finalName = data.name;
    if (!finalName || finalName === 'User' || finalName.trim() === '') {
      finalName = data.email?.split('@')[0] || 'User';
      // Update database if needed
      await supabase
        .from('profiles')
        .update({ name: finalName })
        .eq('id', session.user.id);
      data.name = finalName;
    }

    setProfile(data);
    setName(data.name || data.email?.split('@')[0] || '');
    setLoading(false);
  };

  const handleSave = async () => {
    if (!name.trim()) {
      Alert.alert('Error', 'Please enter a name');
      return;
    }

    setSaving(true);
    try {
      const { error } = await supabase
        .from('profiles')
        .update({ name: name.trim() })
        .eq('id', session?.user?.id);
      
      if (error) throw error;
      
      await fetchProfile();
      setEditing(false);
      Alert.alert('Success', 'Profile updated');
    } catch (err: any) {
      Alert.alert('Error', err.message || 'Failed to update profile');
    } finally {
      setSaving(false);
    }
  };

  const handleLogout = async () => {
    Alert.alert(
      'Sign Out',
      'Are you sure you want to sign out?',
      [
        { text: 'Cancel', style: 'cancel' },
        {
          text: 'Sign Out',
          style: 'destructive',
          onPress: async () => {
            setLoggingOut(true);
            await supabase.auth.signOut();
            await refresh();
            router.replace('/(auth)/signin');
          }
        }
      ]
    );
  };

  if (loading) {
    return (
      <View style={styles.center}>
        <ActivityIndicator size="large" color="#FFC904" />
      </View>
    );
  }

  return (
    <View style={styles.container}>
      <View style={styles.header}>
        <Pressable onPress={() => router.back()} style={styles.backButton} hitSlop={{ top: 10, bottom: 10, left: 10, right: 10 }}>
          <Text style={styles.backText}>← Back</Text>
        </Pressable>
        <Text style={styles.headerTitle}>Profile</Text>
        <View style={{ width: 70 }} />
      </View>

      <View style={styles.content}>
        <View style={styles.profileSection}>
          <View style={styles.avatar}>
            <Text style={styles.avatarText}>
              {(profile?.name || profile?.email?.split('@')[0] || 'U').charAt(0).toUpperCase()}
            </Text>
          </View>
          {editing ? (
            <TextInput
              style={styles.nameInput}
              value={name}
              onChangeText={setName}
              placeholder="Enter your name"
              autoCapitalize="words"
              autoFocus
            />
          ) : (
            <Text style={styles.name}>{profile?.name || profile?.email?.split('@')[0] || 'User'}</Text>
          )}
          <Text style={styles.email}>{profile?.email || session?.user?.email}</Text>
        </View>

        <View style={styles.section}>
          <Text style={styles.sectionTitle}>Account</Text>
          {editing ? (
            <View style={{ flexDirection: 'row', gap: 12 }}>
              <Pressable 
                style={[styles.button, { flex: 1, backgroundColor: '#F5F5F5' }]} 
                onPress={() => { setEditing(false); setName(profile?.name || profile?.email?.split('@')[0] || ''); }}
              >
                <Text style={[styles.buttonText, { color: '#333' }]}>Cancel</Text>
              </Pressable>
              <Pressable 
                style={[styles.button, { flex: 1 }]} 
                onPress={handleSave}
                disabled={saving}
              >
                {saving ? (
                  <ActivityIndicator color="#000" />
                ) : (
                  <Text style={styles.buttonText}>Save</Text>
                )}
              </Pressable>
            </View>
          ) : (
            <Pressable style={styles.button} onPress={() => setEditing(true)}>
              <Text style={styles.buttonText}>Edit Profile</Text>
            </Pressable>
          )}
        </View>

        <View style={styles.section}>
          <Pressable 
            style={[styles.button, styles.logoutButton]} 
            onPress={handleLogout}
            disabled={loggingOut}
          >
            {loggingOut ? (
              <ActivityIndicator color="white" />
            ) : (
              <Text style={styles.logoutText}>Sign Out</Text>
            )}
          </Pressable>
        </View>
      </View>
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
  backButton: { paddingVertical: 12, paddingHorizontal: 8, zIndex: 1 },
  backText: { fontSize: 16, color: '#FFC904', fontWeight: '600' },
  headerTitle: { 
    fontSize: 18, 
    fontWeight: '700', 
    color: '#333',
    flex: 1,
    textAlign: 'center',
    marginHorizontal: -70, // Negative margin to center between buttons
  },
  content: { padding: 16 },
  profileSection: {
    backgroundColor: 'white',
    padding: 32,
    borderRadius: 12,
    alignItems: 'center',
    marginBottom: 16,
  },
  avatar: {
    width: 80,
    height: 80,
    borderRadius: 40,
    backgroundColor: '#FFC904',
    justifyContent: 'center',
    alignItems: 'center',
    marginBottom: 16,
  },
  avatarText: { fontSize: 32, fontWeight: '700', color: '#000000' },
  name: { fontSize: 24, fontWeight: '700', color: '#333', marginBottom: 4 },
  nameInput: { 
    fontSize: 24, 
    fontWeight: '700', 
    color: '#333', 
    textAlign: 'center',
    borderBottomWidth: 2,
    borderBottomColor: '#FFC904',
    paddingVertical: 4,
    marginBottom: 4,
    minWidth: 150
  },
  email: { fontSize: 14, color: '#666' },
  section: { backgroundColor: 'white', padding: 16, borderRadius: 12, marginBottom: 12 },
  sectionTitle: { fontSize: 16, fontWeight: '700', marginBottom: 12, color: '#FFC904' },
  button: {
    backgroundColor: '#FFC904',
    padding: 16,
    borderRadius: 12,
    alignItems: 'center',
  },
  buttonText: { color: '#000000', fontSize: 16, fontWeight: '600' },
  logoutButton: { backgroundColor: '#FF3B30' },
  logoutText: { color: 'white', fontSize: 16, fontWeight: '600' },
});