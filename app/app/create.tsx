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
  const minCapacity = 2; // Minimum capacity (host + at least 1 other)
  const [capacity, setCapacity] = useState(minCapacity);
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
  
  // Temporary picker values
  const [tempDate, setTempDate] = useState<Date>(today);
  const [tempStartTime, setTempStartTime] = useState<Date>(today);
  const [tempEndTime, setTempEndTime] = useState<Date>(today);
  
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
  const [capacityInput, setCapacityInput] = useState(minCapacity.toString());

  const handleSubmit = async () => {
    if (!session?.user) {
      Alert.alert('Error', 'You must be logged in to create a session');
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

    // Check if date is before today (compare only date part, ignore time)
    const selectedDateOnly = new Date(selectedDate.getFullYear(), selectedDate.getMonth(), selectedDate.getDate());
    const todayOnly = new Date(today.getFullYear(), today.getMonth(), today.getDate());
    
    if (selectedDateOnly < todayOnly) {
      Alert.alert('Invalid Date', 'Sessions cannot be scheduled in the past.');
      return;
    }

    setLoading(true);

    try {
      // Ensure profile exists before creating session
      const { data: profile } = await supabase
        .from('profiles')
        .select('id')
        .eq('id', session.user.id)
        .maybeSingle();
      
      if (!profile) {
        // Profile doesn't exist, create it
        const autoName = session.user.email?.split('@')[0] || 'User';
        const { error: profileError } = await supabase
          .from('profiles')
          .insert({
            id: session.user.id,
            email: session.user.email,
            name: autoName,
          });
        
        if (profileError) throw profileError;
      }

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

      // Note: Host is automatically added as a member by the database trigger

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
    if (!isNaN(num) && num >= minCapacity && num <= 50) {
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
            placeholderTextColor="#999"
            value={customSport}
            onChangeText={setCustomSport}
          />
        )}
      </View>

      {/* Date & Time Selection */}
      <View style={styles.section}>
        <Text style={styles.label}>Date *</Text>
        <Pressable style={[styles.dateTimeButton, !selectedDate && styles.dateTimeButtonPlaceholder]} onPress={() => {
          setTempDate(selectedDate || today);
          setShowDatePicker(!showDatePicker);
        }}>
          <Text style={[styles.dateTimeText, !selectedDate && styles.dateTimePlaceholder]}>
            {formatDate(selectedDate)}
          </Text>
        </Pressable>
        {showDatePicker && (
          <View style={styles.pickerContainer}>
            <DateTimePicker
              value={tempDate}
              mode="date"
              display={Platform.OS === 'ios' ? 'spinner' : 'default'}
              minimumDate={today}
              maximumDate={new Date(today.getTime() + 2 * 24 * 60 * 60 * 1000)}
              textColor="#000000"
              onChange={(event, date) => {
                if (Platform.OS === 'ios') {
                  if (event.type === 'set' && date) {
                    setTempDate(date);
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
                <Pressable onPress={() => {
                  setSelectedDate(tempDate);
                  setShowDatePicker(false);
                }} style={styles.pickerAction}>
                  <Text style={styles.pickerActionText}>Done</Text>
                </Pressable>
              </View>
            )}
          </View>
        )}

        <Text style={[styles.label, styles.mt16]}>Start Time *</Text>
        <Pressable style={[styles.dateTimeButton, !startTime && styles.dateTimeButtonPlaceholder]} onPress={() => {
          setTempStartTime(startTime || today);
          setShowStartPicker(!showStartPicker);
        }}>
          <Text style={[styles.dateTimeText, !startTime && styles.dateTimePlaceholder]}>
            {formatTime(startTime)}
          </Text>
        </Pressable>
        {showStartPicker && (
          <View style={styles.pickerContainer}>
            <DateTimePicker
              value={tempStartTime}
              mode="time"
              display={Platform.OS === 'ios' ? 'spinner' : 'default'}
              is24Hour={false}
              minimumDate={getMinimumTime()}
              textColor="#000000"
              onChange={(event, date) => {
                if (Platform.OS === 'ios') {
                  if (event.type === 'set' && date) {
                    setTempStartTime(date);
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
                <Pressable onPress={() => {
                  setStartTime(tempStartTime);
                  setShowStartPicker(false);
                }} style={styles.pickerAction}>
                  <Text style={styles.pickerActionText}>Done</Text>
                </Pressable>
              </View>
            )}
          </View>
        )}

        <Text style={[styles.label, styles.mt16]}>End Time *</Text>
        <Pressable style={[styles.dateTimeButton, !endTime && styles.dateTimeButtonPlaceholder]} onPress={() => {
          setTempEndTime(endTime || today);
          setShowEndPicker(!showEndPicker);
        }}>
          <Text style={[styles.dateTimeText, !endTime && styles.dateTimePlaceholder]}>
            {formatTime(endTime)}
          </Text>
        </Pressable>
        {showEndPicker && (
          <View style={styles.pickerContainer}>
            <DateTimePicker
              value={tempEndTime}
              mode="time"
              display={Platform.OS === 'ios' ? 'spinner' : 'default'}
              is24Hour={false}
              minimumDate={startTime || today}
              textColor="#000000"
              onChange={(event, date) => {
                if (Platform.OS === 'ios') {
                  if (event.type === 'set' && date) {
                    setTempEndTime(date);
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
                <Pressable onPress={() => {
                  setEndTime(tempEndTime);
                  setShowEndPicker(false);
                }} style={styles.pickerAction}>
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
            trackColor={{ false: '#E0E0E0', true: '#FFC904' }}
            thumbColor={useCustomLocation ? 'white' : '#f4f3f4'}
          />
        </View>

        {useCustomLocation ? (
          <TextInput
            style={[styles.input, styles.mt12]}
            placeholder="Enter custom location"
            placeholderTextColor="#999"
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
              style={[styles.counterButton, capacity <= minCapacity && styles.counterButtonDisabled]} 
              onPress={() => setCapacity(Math.max(minCapacity, capacity - 1))}
              disabled={capacity <= minCapacity}
            >
              <Text style={[styles.counterText, capacity <= minCapacity && styles.counterTextDisabled]}>−</Text>
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
            placeholderTextColor="#999"
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
            trackColor={{ false: '#E0E0E0', true: '#FFC904' }}
            thumbColor={equipmentNeeded ? 'white' : '#f4f3f4'}
          />
        </View>
        {equipmentNeeded && (
          <TextInput
            style={[styles.input, styles.mt12]}
            placeholder="Describe equipment needed..."
            placeholderTextColor="#999"
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
          placeholderTextColor="#999"
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
    paddingHorizontal: 16,
    paddingVertical: 12,
    paddingTop: 60,
    backgroundColor: 'white',
    borderBottomWidth: 1,
    borderBottomColor: '#E0E0E0',
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 2 },
    shadowOpacity: 0.05,
    shadowRadius: 4,
    elevation: 2,
  },
  backButton: { paddingVertical: 8, paddingRight: 8 },
  backText: { fontSize: 16, color: '#FFC904', fontWeight: '600' },
  title: { fontSize: 20, fontWeight: '800', color: '#333', flex: 1, textAlign: 'center' },
  section: { 
    padding: 20, 
    backgroundColor: 'white', 
    marginTop: 12, 
    borderRadius: 12,
    marginHorizontal: 12,
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 1 },
    shadowOpacity: 0.05,
    shadowRadius: 3,
    elevation: 1,
  },
  label: { fontSize: 15, fontWeight: '700', color: '#333', marginBottom: 12 },
  mt12: { marginTop: 12 },
  mt16: { marginTop: 16 },
  input: { 
    borderWidth: 1.5, 
    borderColor: '#E0E0E0', 
    padding: 14, 
    borderRadius: 12, 
    fontSize: 16,
    backgroundColor: '#FAFAFA',
    color: '#333',
  },
  textArea: { minHeight: 100, textAlignVertical: 'top', paddingTop: 14 },
  chipContainer: { flexDirection: 'row', gap: 10, marginBottom: 8 },
  chip: { 
    paddingHorizontal: 20, 
    paddingVertical: 10, 
    borderRadius: 24, 
    backgroundColor: '#F5F5F5', 
    borderWidth: 1.5, 
    borderColor: '#E0E0E0',
  },
  chipSelected: { backgroundColor: '#FFC904', borderColor: '#FFC904', borderWidth: 2 },
  chipText: { fontSize: 15, color: '#666', fontWeight: '500' },
  chipTextSelected: { color: '#000000', fontWeight: '700' },
  dateTimeButton: {
    borderWidth: 1.5,
    borderColor: '#E0E0E0',
    padding: 16,
    borderRadius: 12,
    backgroundColor: '#FAFAFA',
  },
  dateTimeButtonPlaceholder: {
    backgroundColor: '#F0F0F0',
    borderColor: '#D0D0D0',
  },
  dateTimeText: { 
    fontSize: 16, 
    color: '#333', 
    fontWeight: '500',
  },
  dateTimePlaceholder: {
    color: '#555',
  },
  pickerContainer: { backgroundColor: 'white', borderRadius: 12, overflow: 'hidden', marginTop: 8 },
  pickerActions: { flexDirection: 'row', justifyContent: 'space-between', padding: 12, backgroundColor: '#F9F9F9' },
  pickerAction: { paddingHorizontal: 16, paddingVertical: 8 },
  pickerActionText: { fontSize: 16, color: '#FFC904', fontWeight: '600' },
  counterContainer: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'center',
    gap: 20,
    marginTop: 16,
    paddingVertical: 8,
  },
  counterButton: {
    width: 48,
    height: 48,
    borderRadius: 24,
    backgroundColor: '#FFC904',
    justifyContent: 'center',
    alignItems: 'center',
    shadowColor: '#FFC904',
    shadowOffset: { width: 0, height: 2 },
    shadowOpacity: 0.2,
    shadowRadius: 4,
    elevation: 3,
  },
  counterButtonDisabled: {
    backgroundColor: '#E0E0E0',
  },
  counterText: {
    fontSize: 24,
    fontWeight: '600',
    color: '#000000',
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
    borderColor: '#FFC904',
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
    backgroundColor: '#FFC904',
    borderRadius: 8,
  },
  doneButtonText: {
    color: '#000000',
    fontWeight: '600',
  },
  toggleRow: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    paddingVertical: 8,
  },
  toggleLabel: { fontSize: 16, color: '#333' },
  buttonContainer: { padding: 16, paddingBottom: 40, marginTop: 8 },
  submitButton: { 
    backgroundColor: '#FFC904', 
    padding: 18, 
    borderRadius: 12, 
    alignItems: 'center',
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 4 },
    shadowOpacity: 0.2,
    shadowRadius: 8,
    elevation: 4,
  },
  buttonDisabled: { opacity: 0.5 },
  submitText: { color: '#000000', fontSize: 17, fontWeight: '700' },
});
