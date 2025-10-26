import { useState, useEffect, useRef } from 'react';
import { View, Text, TextInput, Pressable, StyleSheet, ScrollView, KeyboardAvoidingView, Platform, Alert, ActivityIndicator } from 'react-native';
import { useLocalSearchParams, useRouter } from 'expo-router';
import { supabase } from '../../../lib/supabase';
import { useSession } from '../../../hooks/useSession';

export default function SessionChat() {
  const { id } = useLocalSearchParams<{ id: string }>();
  const { session } = useSession();
  const router = useRouter();
  const [messages, setMessages] = useState<any[]>([]);
  const [newMessage, setNewMessage] = useState('');
  const [loading, setLoading] = useState(true);
  const [sending, setSending] = useState(false);
  const scrollViewRef = useRef<ScrollView>(null);

  useEffect(() => {
    if (id) {
      fetchMessages();
      subscribeToMessages();
    }

    return () => {
      if (id) {
        const channel = supabase.channel(`messages:${id}`);
        channel.unsubscribe();
      }
    };
  }, [id]);

  const fetchMessages = async () => {
    try {
      const { data, error } = await supabase
        .from('messages')
        .select(`
          *,
          profiles(id, name, email)
        `)
        .eq('session_id', id)
        .order('created_at', { ascending: true });

      if (error) throw error;
      setMessages(data || []);
      
      // Scroll to bottom after loading
      setTimeout(() => {
        scrollViewRef.current?.scrollToEnd({ animated: false });
      }, 100);
    } catch (err: any) {
      Alert.alert('Error', 'Failed to load messages');
    } finally {
      setLoading(false);
    }
  };

  const subscribeToMessages = () => {
    const channel = supabase.channel(`messages:${id}`)
      .on('postgres_changes', 
        { 
          event: 'INSERT', 
          schema: 'public', 
          table: 'messages',
          filter: `session_id=eq.${id}`
        }, 
        (payload) => {
          // Fetch user profile for the new message
          supabase
            .from('messages')
            .select('*, profiles(id, name, email)')
            .eq('id', payload.new.id)
            .single()
            .then(({ data }) => {
              if (data) {
                setMessages((prev) => [...prev, data]);
                setTimeout(() => {
                  scrollViewRef.current?.scrollToEnd({ animated: true });
                }, 100);
              }
            });
        }
      )
      .subscribe();
  };

  const handleSendMessage = async () => {
    if (!newMessage.trim() || !session?.user) return;

    setSending(true);

    try {
      const { error } = await supabase
        .from('messages')
        .insert({
          session_id: id,
          user_id: session.user.id,
          body: newMessage.trim(),
        });

      if (error) throw error;

      setNewMessage('');
    } catch (err: any) {
      Alert.alert('Error', 'Failed to send message');
    } finally {
      setSending(false);
    }
  };

  if (loading) {
    return (
      <View style={styles.center}>
        <ActivityIndicator size="large" color="#FFC904" />
      </View>
    );
  }

  return (
    <KeyboardAvoidingView 
      style={styles.container} 
      behavior={Platform.OS === 'ios' ? 'padding' : 'height'}
    >
      {/* Header */}
      <View style={styles.header}>
        <Pressable onPress={() => router.back()} style={styles.backButton} hitSlop={{ top: 10, bottom: 10, left: 10, right: 10 }}>
          <Text style={styles.backText}>← Back</Text>
        </Pressable>
        <Text style={styles.headerTitle}>Session Chat</Text>
        <View style={{ width: 70 }} />
      </View>

      {/* Messages */}
      <ScrollView 
        ref={scrollViewRef}
        style={styles.messagesContainer}
        contentContainerStyle={styles.messagesContent}
      >
        {messages.length === 0 ? (
          <View style={styles.emptyState}>
            <Text style={styles.emptyText}>No messages yet. Start the conversation!</Text>
          </View>
        ) : (
          messages.map((message) => {
            const isCurrentUser = message.user_id === session?.user?.id;
            return (
              <View 
                key={message.id} 
                style={[styles.messageContainer, isCurrentUser && styles.messageContainerSent]}
              >
                {!isCurrentUser && (
                  <View style={styles.avatarContainer}>
                    <View style={styles.messageAvatar}>
                      <Text style={styles.messageAvatarText}>
                        {(message.profiles?.name?.charAt(0) || '?').toUpperCase()}
                      </Text>
                    </View>
                  </View>
                )}
                <View style={[styles.messageBubble, isCurrentUser && styles.messageBubbleSent]}>
                  {!isCurrentUser && (
                    <Text style={styles.senderName}>{message.profiles?.name || 'Unknown'}</Text>
                  )}
                  <Text style={[styles.messageText, isCurrentUser && styles.messageTextSent]}>
                    {message.body}
                  </Text>
                  <Text style={[styles.messageTime, isCurrentUser && styles.messageTimeSent]}>
                    {new Date(message.created_at).toLocaleTimeString('en-US', {
                      hour: 'numeric',
                      minute: '2-digit',
                    })}
                  </Text>
                </View>
              </View>
            );
          })
        )}
      </ScrollView>

      {/* Input */}
      <View style={styles.inputContainer}>
        <TextInput
          style={styles.input}
          placeholder="Type a message..."
          value={newMessage}
          onChangeText={setNewMessage}
          multiline
          placeholderTextColor="#999"
        />
        <Pressable 
          style={[styles.sendButton, sending && styles.sendButtonDisabled]}
          onPress={handleSendMessage}
          disabled={!newMessage.trim() || sending}
        >
          {sending ? (
            <ActivityIndicator color="#000000" size="small" />
          ) : (
            <Text style={styles.sendButtonText}>Send</Text>
          )}
        </Pressable>
      </View>
    </KeyboardAvoidingView>
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
  messagesContainer: { flex: 1, padding: 16, backgroundColor: '#F5F5F7' },
  messagesContent: { paddingBottom: 16 },
  emptyState: { 
    flex: 1, 
    justifyContent: 'center', 
    alignItems: 'center',
    paddingHorizontal: 40,
  },
  emptyText: { 
    fontSize: 16, 
    color: '#999', 
    textAlign: 'center',
    lineHeight: 24,
  },
  messageContainer: {
    marginBottom: 16,
    flexDirection: 'row',
    alignItems: 'flex-end',
  },
  messageContainerSent: {
    flexDirection: 'row-reverse',
    alignItems: 'flex-end',
  },
  avatarContainer: {
    marginRight: 8,
    marginBottom: 2,
  },
  messageAvatar: {
    width: 32,
    height: 32,
    borderRadius: 16,
    backgroundColor: '#FFC904',
    justifyContent: 'center',
    alignItems: 'center',
  },
  messageAvatarText: {
    fontSize: 12,
    fontWeight: '700',
    color: '#000000',
  },
  messageBubble: {
    backgroundColor: '#FFFFFF',
    padding: 12,
    borderRadius: 16,
    maxWidth: '75%',
    borderTopLeftRadius: 4,
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 1 },
    shadowOpacity: 0.05,
    shadowRadius: 2,
    elevation: 1,
  },
  messageBubbleSent: {
    backgroundColor: '#FFC904',
    borderTopLeftRadius: 16,
    borderTopRightRadius: 4,
  },
  senderName: {
    fontSize: 11,
    fontWeight: '700',
    color: '#666',
    marginBottom: 4,
  },
  messageText: {
    fontSize: 15,
    color: '#000000',
    lineHeight: 20,
    marginBottom: 4,
  },
  messageTextSent: {
    color: '#000000',
  },
  messageTime: {
    fontSize: 10,
    color: '#999',
  },
  messageTimeSent: {
    color: '#666',
  },
  inputContainer: {
    flexDirection: 'row',
    padding: 12,
    paddingBottom: 20,
    backgroundColor: 'white',
    borderTopWidth: 1,
    borderTopColor: '#E0E0E0',
    alignItems: 'flex-end',
  },
  input: {
    flex: 1,
    borderWidth: 1,
    borderColor: '#E0E0E0',
    borderRadius: 24,
    paddingHorizontal: 16,
    paddingVertical: 12,
    maxHeight: 100,
    marginRight: 8,
    fontSize: 15,
    backgroundColor: '#F5F5F5',
  },
  sendButton: {
    backgroundColor: '#FFC904',
    paddingHorizontal: 24,
    paddingVertical: 12,
    borderRadius: 24,
    minWidth: 80,
    alignItems: 'center',
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 2 },
    shadowOpacity: 0.1,
    shadowRadius: 4,
    elevation: 2,
  },
  sendButtonDisabled: {
    opacity: 0.5,
  },
  sendButtonText: {
    color: '#000000',
    fontWeight: '700',
    fontSize: 15,
  },
});
