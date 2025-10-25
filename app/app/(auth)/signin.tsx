import { useState } from 'react';
import { View, Text, TextInput, Alert, Pressable, StyleSheet, ActivityIndicator } from 'react-native';
import { useRouter } from 'expo-router';
import { supabase } from '../../lib/supabase';

export default function SignIn() {
  const [email, setEmail] = useState('');
  const [step, setStep] = useState<'email' | 'code'>('email');
  const [code, setCode] = useState('');
  const [loading, setLoading] = useState(false);
  const router = useRouter();

  const sendLink = async () => {
    if (!email.toLowerCase().endsWith('@ucf.edu')) {
      Alert.alert('UCF Only', 'Please use your @ucf.edu email.');
      return;
    }
    setLoading(true);
    const { error } = await supabase.auth.signInWithOtp({
      email,
      options: { 
        shouldCreateUser: true,
        emailRedirectTo: undefined
      }
    });
    setLoading(false);
    if (error) Alert.alert('Error', error.message);
    else {
      Alert.alert('Check Email', 'OTP code sent to your @ucf.edu inbox.');
      setStep('code');
    }
  };

  const verifyCode = async () => {
    if (!code) {
      Alert.alert('Error', 'Please enter the code');
      return;
    }
    setLoading(true);
    const { error } = await supabase.auth.verifyOtp({
      email,
      token: code,
      type: 'magiclink'
    });
    setLoading(false);
    if (error) {
      Alert.alert('Error', error.message);
    } else {
      // Successfully authenticated, redirect to feed
      router.replace('/main');
    }
  };

  if (step === 'code') {
    return (
      <View style={styles.container}>
        <Text style={styles.title}>Enter Code</Text>
        <Text style={styles.subtitle}>Check your email for the OTP code</Text>
        <TextInput
          placeholder="Enter code from email"
          autoCapitalize="none"
          autoCorrect={false}
          keyboardType="default"
          style={styles.input}
          value={code}
          onChangeText={setCode}
          maxLength={20}
        />
        <Pressable 
          style={[styles.button, loading && styles.buttonDisabled]} 
          onPress={verifyCode}
          disabled={loading}
        >
          {loading ? (
            <ActivityIndicator color="white" />
          ) : (
            <Text style={styles.buttonText}>Sign In</Text>
          )}
        </Pressable>
        <Pressable style={[styles.button, styles.secondaryButton]} onPress={() => setStep('email')}>
          <Text style={styles.secondaryButtonText}>Back</Text>
        </Pressable>
      </View>
    );
  }

  return (
    <View style={styles.container}>
      <Text style={styles.title}>PickUp UCF</Text>
      <Text style={styles.subtitle}>UCF email required</Text>
      <TextInput
        placeholder="you@ucf.edu"
        autoCapitalize="none"
        keyboardType="email-address"
        style={styles.input}
        value={email}
        onChangeText={setEmail}
      />
      <Pressable 
        style={[styles.button, loading && styles.buttonDisabled]} 
        onPress={sendLink}
        disabled={loading}
      >
        {loading ? (
          <ActivityIndicator color="white" />
        ) : (
          <Text style={styles.buttonText}>Send OTP code</Text>
        )}
      </Pressable>
    </View>
  );
}

const styles = StyleSheet.create({
  container: { padding: 24, gap: 12 },
  title: { fontSize: 28, fontWeight: '800' },
  subtitle: { color: '#555' },
  input: { borderWidth: 1, padding: 12, borderRadius: 8 },
  button: { backgroundColor: '#007AFF', padding: 12, borderRadius: 8, alignItems: 'center' },
  buttonDisabled: { opacity: 0.5 },
  secondaryButton: { backgroundColor: 'transparent', borderWidth: 1, borderColor: '#007AFF' },
  buttonText: { color: 'white', fontWeight: '600' },
  secondaryButtonText: { color: '#007AFF', fontWeight: '600' },
});
