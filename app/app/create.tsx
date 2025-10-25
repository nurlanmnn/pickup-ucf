import { useState } from 'react';
import { View, Text, ScrollView, TextInput, Pressable, StyleSheet, Alert, ActivityIndicator, Switch, Platform } from 'react-native';
import { useRouter } from 'expo-router';
import DateTimePicker from '@react-native-community/datetimepicker';
import { supabase } from '../lib/supabase';
import { useSession } from '../hooks/useSession';
import { UCF_VENUES } from '../constants/venues';

const SPORTS = ['Basketball', 'Volleyball', 'Flag Football', 'Ultimate Frisbee', 'Tennis', 'Soccer', 'Other'];
const SKILLS = ['Any', 'Beginner', 'Intermediate', 'Advanced'];
const POSITIONS = ['Any', 'Goalie', 'Striker', 'Midfielder', 'Defender', 'Setter', 'Spiker', 'Point Guard', 'Center', 'Other'];

// Helper function to convert skill label to database code
const getSkillCode = (skill: string): string => {
  switch (skill) {
    case 'Beginner': return 'B';
    case 'Intermediate': return 'I';
    case 'Advanced': return 'A';
    case 'Any':
    default: return 'Any';
  }
};

// Format date for display
const formatDate = (date: Date | null): string => {
  if (!date) return 'Select Date';
  
  const today = new Date();
  const tomorrow = new Date(today);
  tomorrow.setDate(tomorrow.getDate() + 1);
  const dayAfter = new Date(today);
  dayAfter.setDate(dayAfter.getDate() + 2);

  if (date.toDateString() === today.toDateString()) return 'Today';
  if (date.toDateString() === tomorrow.toDateString()) return 'Tomorrow';
  if (date.toDateString() === dayAfter.toDateString()) return 'Day After';
  
  return date.toLocaleDateString('en-US', { month: 'short', day: 'numeric' });
};

// Format time with AM/PM
const formatTime = (time: Date | null): string => {
  if (!time) return 'Select Time';
  return time.toLocaleTimeString('en-US', { hour: 'numeric', minute: '2-digit', hour12: true });
};

export default function Create() {
  const { session } = useSession();
  const router = useRouter();
  const [loading, setLoading] = useState(false);
  
  // Form state
  const [sport, setSport] = useState('');
  const [customSport, setCustomSport] = useState('');
  const [notes, setNotes] = useState('');
  const [address, setAddress] = useState('');
  const [capacity, setCapacity] = useState(10);
  const [skillTarget, setSkillTarget] = useState('');
  const [selectedPositions, setSelectedPositions] = useState<string[]>([]);
  const [equipmentNeeded, setEquipmentNeeded] = useState(false);
  const [equipmentDescription, setEquipmentDescription] = useState('');
  const [otherPosition, setOtherPosition] = useState('');
  
  // Date & Time state - now nullable
  const today = new Date();
  const [selectedDate, setSelectedDate] = useState<Date | null>(null);
  const [startTime, setStartTime] = useState<Date | null>(null);
  const [endTime, setEndTime] = useState<Date | null>(null);
  
  // Picker visibility
  const [showDatePicker, setShowDatePicker] = useState(false);
  const [showStartPicker, setShowStartPicker] = useState(false);
  const [showEndPicker, setShowEndPicker] = useState(false);
  
  // Location selection
  const [useCustomLocation, setUseCustomLocation] = useState(false);
  const [customLocation, setCustomLocation] = useState('');
  const [selectedVenue, setSelectedVenue] = useState('');
  
  // Capacity editing
  const [editingCapacity, setEditingCapacity] = useState(false);
  const [capacityInput, setCapacityInput] = useState('10');

  const handleSubmit = async () => {
    if (!session?.user) {
      Alert.alert('Error', 'You must be logged in to create a session');
      return;
    }

    // Check if profile is complete
    const { data: profile } = await supabase
      .from('profiles')
      .select('name')
      .eq('id', session.user.id)
      .single();

    if (!profile?.name) {
      Alert.alert(
        'Complete Your Profile',
        'You need to complete your profile before creating sessions. Please add your name.',
        [
          { text: 'Cancel', style: 'cancel' },
          { text: 'Go to Profile', onPress: () => router.push('/profile-setup') }
        ]
      );
      return;
    }

    // Validation
    if (!sport) {
      Alert.alert('Error', 'Please select a sport');
      return;
    }

    if (sport === 'Other' && !customSport.trim()) {
      Alert.alert('Error', 'Please enter a custom sport name');
      return;
    }

    if (!selectedDate) {
      Alert.alert('Error', 'Please select a date');
      return;
    }

    if (!startTime) {
      Alert.alert('Error', 'Please select a start time');
      return;
    }

    if (!endTime) {
      Alert.alert('Error', 'Please select an end time');
      return;
    }

    if (!selectedVenue && !customLocation.trim() && !useCustomLocation) {
      Alert.alert('Error', 'Please select or enter a location');
      return;
    }

    // Check if end time is after start time
    const combinedStart = new Date(selectedDate);
    combinedStart.setHours(startTime.getHours(), startTime.getMinutes(), 0, 0);
    
    const combinedEnd = new Date(selectedDate);
    combinedEnd.setHours(endTime.getHours(), endTime.getMinutes(), 0, 0);
    
    if (combinedEnd <= combinedStart) {
      Alert.alert('Invalid Time', 'End time must be after start time.');
      return;
    }

    // Check if start time is at least 15 minutes from now
    const fifteenMinutesFromNow = new Date(today.getTime() + 15 * 60 * 1000);
    if (combinedStart < fifteenMinutesFromNow) {
      Alert.alert('Invalid Time', 'Start time must be at least 15 minutes from now.');
      return;
    }

    // Check if session is too far in the future
    const twoDaysFromNow = new Date(today);
    twoDaysFromNow.setDate(twoDaysFromNow.getDate() + 2);
    twoDaysFromNow.setHours(23, 59, 59, 999);
    
    if (combinedStart > twoDaysFromNow) {
      Alert.alert('Invalid Date', 'Sessions can only be scheduled up to 2 days ahead from today.');
      return;
    }

    // Check if date is before today
    if (selectedDate.toDateString() < today.toDateString()) {
      Alert.alert('Invalid Date', 'Sessions cannot be scheduled in the past.');
      return;
    }

    setLoading(true);

    try {
      // Determine final address
      let finalAddress = '';
      if (useCustomLocation) {
        finalAddress = customLocation.trim() || '';
      } else if (selectedVenue) {
        finalAddress = UCF_VENUES.find(v => v.key === selectedVenue)?.name || '';
      }

      const { data, error } = await supabase
        .from('sessions')
        .insert({
          sport: sport === 'Other' ? 'Custom' : sport,
          custom_sport: sport === 'Other' ? customSport.trim() : null,
          notes: notes.trim() || null,
          address: finalAddress || null,
          capacity: capacity,
          skill_target: skillTarget ? getSkillCode(skillTarget) : 'Any',
          positions: selectedPositions.length > 0 && !selectedPositions.includes('Any') ? selectedPositions.filter(p => p !== 'Other') : null,
          equipment_needed: equipmentNeeded,
          is_indoor: false,
          starts_at: combinedStart.toISOString(),
          ends_at: combinedEnd.toISOString(),
          host_id: session.user.id,
          is_open: true,
        })
        .select()
        .single();

      if (error) throw error;

      Alert.alert('Success', 'Session created!', [
        { text: 'OK', onPress: () => router.back() }
      ]);
    } catch (err: any) {
      Alert.alert('Error', err.message);
    } finally {
      setLoading(false);
    }
  };

  const togglePosition = (position: string) => {
    if (position === 'Any') {
      if (selectedPositions.includes('Any')) {
        setSelectedPositions([]);
      } else {
        setSelectedPositions(['Any']);
      }
    } else if (position === 'Other') {
      if (selectedPositions.includes('Other')) {
        setSelectedPositions(prev => prev.filter(p => p !== 'Other'));
        setOtherPosition('');
      } else {
        setSelectedPositions(prev => [...prev.filter(p => p !== 'Any'), 'Other']);
      }
    } else {
      setSelectedPositions(prev => {
        const newPositions = prev.filter(p => p !== 'Any');
        if (newPositions.includes(position)) {
          return newPositions.filter(p => p !== position);
        } else {
          return [...newPositions.filter(p => p !== 'Other'), position];
        }
      });
    }
  };

  const handleCapacityChange = (value: string) => {
    setCapacityInput(value);
    const num = parseInt(value, 10);
    if (!isNaN(num) && num >= 1 && num <= 50) {
      setCapacity(num);
    }
  };

  const getMinimumTime = () => {
    if (!selectedDate) return today;
    const minTime = new Date(today.getTime() + 15 * 60 * 1000);
    if (selectedDate.toDateString() === today.toDateString()) {
      return minTime;
    }
    return new Date(selectedDate.setHours(0, 0, 0, 0));
  };

  return (
    <ScrollView style={styles.container}>
      {/* Header with Back Button */}
      <View style={styles.header}>
        <Pressable onPress={() => router.back()} style={styles.backButton}>
          <Text style={styles.backText}>← Back</Text>
        </Pressable>
        <Text style={styles.title}>Create Session</Text>
        <View style={{ width: 50 }} />
      </View>

      {/* Sport Selection */}
      <View style={styles.section}>
        <Text style={styles.label}>Sport *</Text>
        <ScrollView horizontal showsHorizontalScrollIndicator={false} style={styles.chipContainer}>
          {SPORTS.map((s) => (
            <Pressable
              key={s}
              style={[styles.chip, sport === s && styles.chipSelected]}
              onPress={() => setSport(sport === s ? '' : s)}
            >
              <Text style={[styles.chipText, sport === s && styles.chipTextSelected]}>{s}</Text>
            </Pressable>
          ))}
        </ScrollView>
        {sport === 'Other' && (
          <TextInput
            style={[styles.input, styles.mt12]}
            placeholder="Enter sport name"
            value={customSport}
            onChangeText={setCustomSport}
          />
        )}
      </View>

      {/* Date & Time Selection */}
      <View style={styles.section}>
        <Text style={styles.label}>Date *</Text>
        <Pressable style={styles.dateTimeButton} onPress={() => setShowDatePicker(!showDatePicker)}>
          <Text style={styles.dateTimeText}>{formatDate(selectedDate)}</Text>
        </Pressable>
        {showDatePicker && (
          <View style={styles.pickerContainer}>
            <DateTimePicker
              value={selectedDate || today}
              mode="date"
              display={Platform.OS === 'ios' ? 'spinner' : 'default'}
              minimumDate={today}
              maximumDate={new Date(today.getTime() + 2 * 24 * 60 * 60 * 1000)}
              onChange={(event, date) => {
                if (Platform.OS === 'ios') {
                  if (event.type === 'set' && date) {
                    setSelectedDate(date);
                  }
                  if (event.type === 'dismissed') {
                    setShowDatePicker(false);
                  }
                } else {
                  setShowDatePicker(false);
                  if (date) {
                    setSelectedDate(date);
                  }
                }
              }}
            />
            {Platform.OS === 'ios' && (
              <View style={styles.pickerActions}>
                <Pressable onPress={() => setShowDatePicker(false)} style={styles.pickerAction}>
                  <Text style={styles.pickerActionText}>Cancel</Text>
                </Pressable>
                <Pressable onPress={() => setShowDatePicker(false)} style={styles.pickerAction}>
                  <Text style={styles.pickerActionText}>Done</Text>
                </Pressable>
              </View>
            )}
          </View>
        )}

        <Text style={[styles.label, styles.mt16]}>Start Time *</Text>
        <Pressable style={styles.dateTimeButton} onPress={() => setShowStartPicker(!showStartPicker)}>
          <Text style={styles.dateTimeText}>{formatTime(startTime)}</Text>
        </Pressable>
        {showStartPicker && (
          <View style={styles.pickerContainer}>
            <DateTimePicker
              value={startTime || today}
              mode="time"
              display={Platform.OS === 'ios' ? 'spinner' : 'default'}
              is24Hour={false}
              minimumDate={getMinimumTime()}
              onChange={(event, date) => {
                if (Platform.OS === 'ios') {
                  if (event.type === 'set' && date) {
                    setStartTime(date);
                  }
                  if (event.type === 'dismissed') {
                    setShowStartPicker(false);
                  }
                } else {
                  setShowStartPicker(false);
                  if (date) setStartTime(date);
                }
              }}
            />
            {Platform.OS === 'ios' && (
              <View style={styles.pickerActions}>
                <Pressable onPress={() => setShowStartPicker(false)} style={styles.pickerAction}>
                  <Text style={styles.pickerActionText}>Cancel</Text>
                </Pressable>
                <Pressable onPress={() => setShowStartPicker(false)} style={styles.pickerAction}>
                  <Text style={styles.pickerActionText}>Done</Text>
                </Pressable>
              </View>
            )}
          </View>
        )}

        <Text style={[styles.label, styles.mt16]}>End Time *</Text>
        <Pressable style={styles.dateTimeButton} onPress={() => setShowEndPicker(!showEndPicker)}>
          <Text style={styles.dateTimeText}>{formatTime(endTime)}</Text>
        </Pressable>
        {showEndPicker && (
          <View style={styles.pickerContainer}>
            <DateTimePicker
              value={endTime || today}
              mode="time"
              display={Platform.OS === 'ios' ? 'spinner' : 'default'}
              is24Hour={false}
              minimumDate={startTime || today}
              onChange={(event, date) => {
                if (Platform.OS === 'ios') {
                  if (event.type === 'set' && date) {
                    setEndTime(date);
                  }
                  if (event.type === 'dismissed') {
                    setShowEndPicker(false);
                  }
                } else {
                  setShowEndPicker(false);
                  if (date) setEndTime(date);
                }
              }}
            />
            {Platform.OS === 'ios' && (
              <View style={styles.pickerActions}>
                <Pressable onPress={() => setShowEndPicker(false)} style={styles.pickerAction}>
                  <Text style={styles.pickerActionText}>Cancel</Text>
                </Pressable>
                <Pressable onPress={() => setShowEndPicker(false)} style={styles.pickerAction}>
                  <Text style={styles.pickerActionText}>Done</Text>
                </Pressable>
              </View>
            )}
          </View>
        )}
      </View>

      {/* Location Selection */}
      <View style={styles.section}>
        <Text style={styles.label}>Location</Text>
        
        <View style={styles.toggleRow}>
          <Text style={styles.toggleLabel}>Use custom location</Text>
          <Switch
            value={useCustomLocation}
            onValueChange={setUseCustomLocation}
            trackColor={{ false: '#E0E0E0', true: '#007AFF' }}
            thumbColor={useCustomLocation ? 'white' : '#f4f3f4'}
          />
        </View>

        {useCustomLocation ? (
          <TextInput
            style={[styles.input, styles.mt12]}
            placeholder="Enter custom location"
            value={customLocation}
            onChangeText={setCustomLocation}
          />
        ) : (
          <ScrollView horizontal showsHorizontalScrollIndicator={false} style={[styles.chipContainer, styles.mt12]}>
            {UCF_VENUES.filter(v => v.key !== 'other').map((venue) => (
              <Pressable
                key={venue.key}
                style={[styles.chip, selectedVenue === venue.key && styles.chipSelected]}
                onPress={() => setSelectedVenue(selectedVenue === venue.key ? '' : venue.key)}
              >
                <Text style={[styles.chipText, selectedVenue === venue.key && styles.chipTextSelected]}>{venue.name}</Text>
              </Pressable>
            ))}
          </ScrollView>
        )}
      </View>

      {/* Capacity & Skill */}
      <View style={styles.section}>
        <Text style={styles.label}>Capacity *</Text>
        {editingCapacity ? (
          <View style={styles.counterContainer}>
            <Pressable onPress={() => setEditingCapacity(false)} style={styles.doneButton}>
              <Text style={styles.doneButtonText}>Done</Text>
            </Pressable>
            <TextInput
              style={styles.capacityInput}
              value={capacityInput}
              onChangeText={handleCapacityChange}
              keyboardType="numeric"
              autoFocus
              onBlur={() => setEditingCapacity(false)}
            />
          </View>
        ) : (
          <View style={styles.counterContainer}>
            <Pressable 
              style={[styles.counterButton, capacity <= 1 && styles.counterButtonDisabled]} 
              onPress={() => setCapacity(Math.max(1, capacity - 1))}
              disabled={capacity <= 1}
            >
              <Text style={[styles.counterText, capacity <= 1 && styles.counterTextDisabled]}>−</Text>
            </Pressable>
            <Pressable onPress={() => setEditingCapacity(true)} style={styles.capacityDisplay}>
              <Text style={styles.counterValue}>{capacity}</Text>
            </Pressable>
            <Pressable 
              style={[styles.counterButton, capacity >= 50 && styles.counterButtonDisabled]} 
              onPress={() => setCapacity(Math.min(50, capacity + 1))}
              disabled={capacity >= 50}
            >
              <Text style={[styles.counterText, capacity >= 50 && styles.counterTextDisabled]}>+</Text>
            </Pressable>
          </View>
        )}
        
        <Text style={[styles.label, styles.mt16]}>Skill Level</Text>
        <ScrollView horizontal showsHorizontalScrollIndicator={false} style={[styles.chipContainer, styles.mt12]}>
          {SKILLS.map((s) => (
            <Pressable
              key={s}
              style={[styles.chip, skillTarget === s && styles.chipSelected]}
              onPress={() => setSkillTarget(skillTarget === s ? '' : s)}
            >
              <Text style={[styles.chipText, skillTarget === s && styles.chipTextSelected]}>{s}</Text>
            </Pressable>
          ))}
        </ScrollView>
      </View>

      {/* Positions */}
      <View style={styles.section}>
        <Text style={styles.label}>Positions Needed (Optional)</Text>
        <ScrollView horizontal showsHorizontalScrollIndicator={false} style={[styles.chipContainer, styles.mt12]}>
          {POSITIONS.map((p) => (
            <Pressable
              key={p}
              style={[styles.chip, selectedPositions.includes(p) && styles.chipSelected]}
              onPress={() => togglePosition(p)}
            >
              <Text style={[styles.chipText, selectedPositions.includes(p) && styles.chipTextSelected]}>{p}</Text>
            </Pressable>
          ))}
        </ScrollView>
        
        {selectedPositions.includes('Other') && (
          <TextInput
            style={[styles.input, styles.mt12]}
            placeholder="Specify position"
            value={otherPosition}
            onChangeText={setOtherPosition}
          />
        )}
      </View>

      {/* Equipment Needed */}
      <View style={styles.section}>
        <View style={styles.toggleRow}>
          <Text style={styles.toggleLabel}>Equipment Needed</Text>
          <Switch
            value={equipmentNeeded}
            onValueChange={setEquipmentNeeded}
            trackColor={{ false: '#E0E0E0', true: '#007AFF' }}
            thumbColor={equipmentNeeded ? 'white' : '#f4f3f4'}
          />
        </View>
        {equipmentNeeded && (
          <TextInput
            style={[styles.input, styles.mt12]}
            placeholder="Describe equipment needed..."
            value={equipmentDescription}
            onChangeText={setEquipmentDescription}
          />
        )}
      </View>

      {/* Notes */}
      <View style={styles.section}>
        <Text style={styles.label}>Additional Notes</Text>
        <TextInput
          style={[styles.input, styles.textArea, styles.mt12]}
          placeholder="Any additional info..."
          value={notes}
          onChangeText={setNotes}
          multiline
          numberOfLines={3}
        />
      </View>

      {/* Submit Button */}
      <View style={styles.buttonContainer}>
        <Pressable
          style={[styles.submitButton, loading && styles.buttonDisabled]}
          onPress={handleSubmit}
          disabled={loading}
        >
          {loading ? (
            <ActivityIndicator color="white" />
          ) : (
            <Text style={styles.submitText}>Create Session</Text>
          )}
        </Pressable>
      </View>
    </ScrollView>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1, backgroundColor: '#F5F5F5' },
  header: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    padding: 16,
    paddingTop: 60,
    backgroundColor: 'white',
    borderBottomWidth: 1,
    borderBottomColor: '#E0E0E0',
  },
  backButton: { paddingVertical: 8 },
  backText: { fontSize: 16, color: '#007AFF', fontWeight: '600' },
  title: { fontSize: 20, fontWeight: '800', color: '#333' },
  section: { padding: 16, backgroundColor: 'white', marginTop: 8 },
  label: { fontSize: 14, fontWeight: '600', color: '#333' },
  mt12: { marginTop: 12 },
  mt16: { marginTop: 16 },
  input: { borderWidth: 1, borderColor: '#E0E0E0', padding: 12, borderRadius: 8, fontSize: 16 },
  textArea: { minHeight: 80, textAlignVertical: 'top' },
  chipContainer: { flexDirection: 'row', gap: 8 },
  chip: { paddingHorizontal: 16, paddingVertical: 8, borderRadius: 20, backgroundColor: '#F0F0F0', borderWidth: 1, borderColor: '#E0E0E0' },
  chipSelected: { backgroundColor: '#007AFF', borderColor: '#007AFF' },
  chipText: { fontSize: 14, color: '#666' },
  chipTextSelected: { color: 'white', fontWeight: '600' },
  dateTimeButton: {
    borderWidth: 1,
    borderColor: '#E0E0E0',
    padding: 16,
    borderRadius: 8,
    backgroundColor: '#FAFAFA',
  },
  dateTimeText: { fontSize: 16, color: '#333' },
  pickerContainer: { backgroundColor: 'white', borderRadius: 12, overflow: 'hidden', marginTop: 8 },
  pickerActions: { flexDirection: 'row', justifyContent: 'space-between', padding: 12, backgroundColor: '#F9F9F9' },
  pickerAction: { paddingHorizontal: 16, paddingVertical: 8 },
  pickerActionText: { fontSize: 16, color: '#007AFF', fontWeight: '600' },
  counterContainer: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'center',
    gap: 16,
    marginTop: 12,
  },
  counterButton: {
    width: 44,
    height: 44,
    borderRadius: 22,
    backgroundColor: '#007AFF',
    justifyContent: 'center',
    alignItems: 'center',
  },
  counterButtonDisabled: {
    backgroundColor: '#E0E0E0',
  },
  counterText: {
    fontSize: 24,
    fontWeight: '600',
    color: 'white',
  },
  counterTextDisabled: {
    color: '#999',
  },
  capacityDisplay: {
    minWidth: 60,
    alignItems: 'center',
  },
  capacityInput: {
    fontSize: 24,
    fontWeight: '600',
    color: '#333',
    textAlign: 'center',
    minWidth: 60,
    borderWidth: 1,
    borderColor: '#007AFF',
    borderRadius: 8,
    padding: 8,
  },
  counterValue: {
    fontSize: 24,
    fontWeight: '600',
    color: '#333',
    textAlign: 'center',
  },
  doneButton: {
    paddingHorizontal: 12,
    paddingVertical: 8,
    backgroundColor: '#007AFF',
    borderRadius: 8,
  },
  doneButtonText: {
    color: 'white',
    fontWeight: '600',
  },
  toggleRow: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    paddingVertical: 8,
  },
  toggleLabel: { fontSize: 16, color: '#333' },
  buttonContainer: { padding: 16, paddingBottom: 32 },
  submitButton: { backgroundColor: '#007AFF', padding: 16, borderRadius: 12, alignItems: 'center' },
  buttonDisabled: { opacity: 0.5 },
  submitText: { color: 'white', fontSize: 16, fontWeight: '600' },
});
