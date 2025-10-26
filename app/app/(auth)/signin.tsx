import { useState } from 'react';
import { View, Text, TextInput, Alert, Pressable, StyleSheet, ActivityIndicator, KeyboardAvoidingView, Platform, ScrollView } from 'react-native';
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
        shouldCreateUser: true
      }
    });
    
    setLoading(false);
    if (error) {
      Alert.alert('Error', error.message);
    } else {
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
    const { error, data } = await supabase.auth.verifyOtp({
      email,
      token: code,
      type: 'email'
    });
    
    setLoading(false);
    
    if (error) {
      Alert.alert('Error', error.message);
    } else if (data?.user) {
      // Successfully authenticated, redirect to feed
      router.replace('/main');
    }
  };

  if (step === 'code') {
    return (
      <KeyboardAvoidingView 
        style={styles.container} 
        behavior={Platform.OS === 'ios' ? 'padding' : 'height'}
      >
        <ScrollView contentContainerStyle={styles.scrollContent} keyboardShouldPersistTaps="handled">
          <View style={styles.logoContainer}>
            <View style={styles.logoCircle}>
              <Text style={styles.logoText}>🏈</Text>
            </View>
          </View>
          
          <Text style={styles.title}>Enter Verification Code</Text>
          <Text style={styles.subtitle}>We sent a code to your email{'\n'}{email}</Text>
          
          <View style={styles.inputContainer}>
            <Text style={styles.inputLabel}>Verification Code</Text>
            <TextInput
              placeholder="Enter 6-digit code"
              placeholderTextColor="#999"
              autoCapitalize="none"
              autoCorrect={false}
              keyboardType="number-pad"
              style={styles.input}
              value={code}
              onChangeText={setCode}
              maxLength={6}
              autoFocus
            />
          </View>
          
        <Pressable 
          style={[styles.button, loading && styles.buttonDisabled]} 
          onPress={verifyCode}
          disabled={loading}
        >
          {loading ? (
            <ActivityIndicator color="#000000" />
          ) : (
            <Text style={styles.buttonText}>Verify & Sign In</Text>
          )}
        </Pressable>
          
          <Pressable style={styles.backButton} onPress={() => setStep('email')}>
            <Text style={styles.backButtonText}>← Back to Email</Text>
          </Pressable>
          
          <Pressable style={styles.resendButton} onPress={() => { setStep('email'); Alert.alert('Info', 'You can request a new code by entering your email again.'); }}>
            <Text style={styles.resendText}>Didn't receive code?</Text>
          </Pressable>
        </ScrollView>
      </KeyboardAvoidingView>
    );
  }

  return (
    <KeyboardAvoidingView 
      style={styles.container} 
      behavior={Platform.OS === 'ios' ? 'padding' : 'height'}
    >
      <ScrollView contentContainerStyle={styles.scrollContent} keyboardShouldPersistTaps="handled">
        <View style={styles.logoContainer}>
          <View style={styles.logoCircle}>
            <Text style={styles.logoText}>🏈</Text>
          </View>
        </View>
        
        <View style={styles.header}>
          <Text style={styles.title}>PickUp </Text>
          <Text style={[styles.title, styles.titleUCF]}>UCF</Text>
          <Text style={styles.subtitle}>Connect with UCF students for sports sessions</Text>
        </View>
        
        <View style={styles.inputContainer}>
          <Text style={styles.inputLabel}>UCF Email</Text>
          <TextInput
            placeholder="you@ucf.edu"
            placeholderTextColor="#999"
            autoCapitalize="none"
            keyboardType="email-address"
            autoComplete="email"
            autoCorrect={false}
            style={styles.input}
            value={email}
            onChangeText={setEmail}
            autoFocus
          />
        </View>
        
        <Pressable 
          style={[styles.button, loading && styles.buttonDisabled]} 
          onPress={sendLink}
          disabled={loading}
        >
          {loading ? (
            <ActivityIndicator color="#000000" />
          ) : (
            <Text style={styles.buttonText}>Sign In</Text>
          )}
        </Pressable>
        
        <Text style={styles.disclaimer}>
          By continuing, you agree to connect with other UCF students for sports activities
        </Text>
      </ScrollView>
    </KeyboardAvoidingView>
  );
}

const styles = StyleSheet.create({
  container: { 
    flex: 1, 
    backgroundColor: '#FFFFFF',
  },
  scrollContent: {
    flexGrow: 1,
    padding: 24,
    paddingTop: 80,
    paddingBottom: 40,
  },
  logoContainer: {
    alignItems: 'center',
    marginBottom: 48,
  },
  logoCircle: {
    width: 100,
    height: 100,
    borderRadius: 50,
    backgroundColor: '#FFC904', // UCF Gold
    justifyContent: 'center',
    alignItems: 'center',
    marginBottom: 8,
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 4 },
    shadowOpacity: 0.2,
    shadowRadius: 8,
    elevation: 4,
  },
  logoText: {
    fontSize: 48,
    fontWeight: 'bold',
  },
  header: {
    marginBottom: 32,
    alignItems: 'center',
  },
  titleContainer: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'center',
    marginBottom: 8,
  },
  title: { 
    fontSize: 32, 
    fontWeight: '800',
    color: '#000000',
  },
  titleUCF: {
    color: '#FFC904', // UCF Gold
  },
  subtitle: { 
    color: '#666666',
    fontSize: 16,
    textAlign: 'center',
    lineHeight: 22,
  },
  inputContainer: {
    marginBottom: 24,
  },
  inputLabel: {
    fontSize: 14,
    fontWeight: '600',
    color: '#333333',
    marginBottom: 8,
  },
  input: { 
    borderWidth: 1.5,
    borderColor: '#E0E0E0',
    padding: 16, 
    borderRadius: 12,
    fontSize: 16,
    backgroundColor: '#FAFAFA',
    color: '#000000',
  },
  button: { 
    backgroundColor: '#FFC904', // UCF Gold
    padding: 16, 
    borderRadius: 12, 
    alignItems: 'center',
    marginBottom: 16,
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 2 },
    shadowOpacity: 0.15,
    shadowRadius: 4,
    elevation: 3,
  },
  buttonDisabled: { 
    opacity: 0.5,
  },
  buttonText: { 
    color: '#000000', 
    fontWeight: '700',
    fontSize: 16,
  },
  backButton: {
    padding: 12,
    alignItems: 'center',
  },
  backButtonText: {
    color: '#FFC904', // UCF Gold
    fontSize: 15,
    fontWeight: '600',
  },
  resendButton: {
    padding: 12,
    alignItems: 'center',
    marginTop: 8,
  },
  resendText: {
    color: '#666666',
    fontSize: 14,
  },
  disclaimer: {
    fontSize: 12,
    color: '#999999',
    textAlign: 'center',
    marginTop: 24,
    paddingHorizontal: 20,
    lineHeight: 18,
  },
});
