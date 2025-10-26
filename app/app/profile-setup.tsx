import { useState, useEffect } from 'react';
import { View, Text, TextInput, Pressable, StyleSheet, Alert, ActivityIndicator } from 'react-native';
import { useRouter } from 'expo-router';
import { supabase } from '../lib/supabase';
import { useSession } from '../hooks/useSession';

export default function ProfileSetup() {
  const { session, refresh } = useSession();
  const router = useRouter();
  const [name, setName] = useState('');
  const [loading, setLoading] = useState(false);
  const [fetching, setFetching] = useState(true);

  useEffect(() => {
    if (session?.user) {
      supabase
        .from('profiles')
        .select('name')
        .eq('id', session.user.id)
        .maybeSingle()
        .then(({ data }) => {
          if (data?.name) setName(data.name);
          setFetching(false);
        });
    }
  }, [session]);

  const handleSubmit = async () => {
    if (!name.trim()) {
      Alert.alert('Error', 'Please enter your name');
      return;
    }

    if (!session?.user) {
      Alert.alert('Error', 'You must be logged in');
      return;
    }

    setLoading(true);

    try {
      const { error } = await supabase
        .from('profiles')
        .update({ name: name.trim() })
        .eq('id', session.user.id);

      if (error) throw error;

      await refresh();
      router.replace('/main');
    } catch (err: any) {
      Alert.alert('Error', err.message);
    } finally {
      setLoading(false);
    }
  };

  return (
    <View style={styles.container}>
      <Text style={styles.title}>Welcome to PickUp UCF!</Text>
      <Text style={styles.subtitle}>Let's set up your profile</Text>

      <View style={styles.form}>
        <Text style={styles.label}>Display Name</Text>
        <TextInput
          style={styles.input}
          placeholder="Enter your name"
          value={name}
          onChangeText={setName}
          autoCapitalize="words"
          autoFocus
        />

        <View style={styles.buttonRow}>
          <Pressable
            style={[styles.button, styles.cancelButton]}
            onPress={() => router.back()}
          >
            <Text style={styles.cancelText}>Cancel</Text>
          </Pressable>
          
          <Pressable
            style={[styles.button, styles.continueButton, loading && styles.buttonDisabled]}
            onPress={handleSubmit}
            disabled={loading}
          >
            {loading ? (
              <ActivityIndicator color="#000000" />
            ) : (
              <Text style={styles.buttonText}>Save</Text>
            )}
          </Pressable>
        </View>
      </View>
    </View>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1, justifyContent: 'center', padding: 24, backgroundColor: 'white' },
  title: { fontSize: 28, fontWeight: '800', textAlign: 'center', marginBottom: 8, color: '#FFC904' },
  subtitle: { fontSize: 16, textAlign: 'center', marginBottom: 48, color: '#666' },
  form: { gap: 24 },
  label: { fontSize: 14, fontWeight: '600', color: '#333', marginBottom: 8 },
  input: { borderWidth: 1, borderColor: '#E0E0E0', padding: 16, borderRadius: 8, fontSize: 16 },
  buttonRow: { flexDirection: 'row', gap: 12 },
  button: { flex: 1, padding: 16, borderRadius: 12, alignItems: 'center' },
  cancelButton: { backgroundColor: '#F5F5F5', borderWidth: 1, borderColor: '#E0E0E0' },
  continueButton: { backgroundColor: '#FFC904' },
  buttonDisabled: { opacity: 0.5 },
  buttonText: { color: '#000000', fontSize: 16, fontWeight: '600' },
  cancelText: { color: '#333', fontSize: 16, fontWeight: '600' },
});