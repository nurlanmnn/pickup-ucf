// Quick test script to create a session
// Run this with: node test-session.js

const supabaseUrl = process.env.EXPO_PUBLIC_SUPABASE_URL;
const supabaseKey = process.env.EXPO_PUBLIC_SUPABASE_ANON_KEY;

if (!supabaseUrl || !supabaseKey) {
  console.error('Missing Supabase credentials in .env file');
  process.exit(1);
}

// This will only work if you're authenticated
console.log('To create a test session:');
console.log('1. Open the app and sign in');
console.log('2. Click "+ Create" button');
console.log('3. Fill in the form:');
console.log('   - Sport: Basketball');
console.log('   - Date: 2025-10-25');
console.log('   - Start Time: 19:00');
console.log('   - End Time: 21:00');
console.log('   - Location: IM Fields Court 1');
console.log('   - Capacity: 10');
console.log('4. Click "Create Session"');
console.log('\nOr use the app to create it directly!');
