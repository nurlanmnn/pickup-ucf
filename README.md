# PickUp UCF 🏀⚽🎾

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![TypeScript](https://img.shields.io/badge/TypeScript-007ACC?logo=typescript&logoColor=white)](https://www.typescriptlang.org/)
[![React Native](https://img.shields.io/badge/React_Native-61DAFB?logo=react&logoColor=black)](https://reactnative.dev/)
[![Expo](https://img.shields.io/badge/Expo-000000?logo=expo&logoColor=white)](https://expo.dev/)
[![Supabase](https://img.shields.io/badge/Supabase-3ECF8E?logo=supabase&logoColor=white)](https://supabase.com/)

A mobile app designed exclusively for **UCF students** to connect and organize pickup sports sessions. Find people to play your favorite sports with, or create your own sessions for others to join.

## 🌟 Features

- **🏋️ Create Sessions**: Schedule pickup games with detailed settings (sport, location, time, capacity, skill level)
- **🔍 Discover Activities**: Browse upcoming sessions with a powerful search filter
- **📍 UCF Venues**: Choose from popular UCF sports venues or add custom locations
- **💬 Real-time Chat**: Communicate with fellow players in session chat rooms
- **👤 Profiles**: Manage your profile and track your participation
- **🎯 Skill Matching**: Find players at your skill level (Beginner, Intermediate, Advanced)
- **⏰ Flexible Scheduling**: Plan sessions up to 2 days in advance
- **🔒 UCF Exclusive**: Verified UCF email authentication ensures a safe, student-only community

## 🎮 Supported Sports

- Basketball
- Volleyball
- Flag Football
- Ultimate Frisbee
- Tennis
- Soccer
- Custom Sports (add your own!)

## 🛠️ Tech Stack

- **Frontend**: React Native with Expo
- **Backend**: Supabase (PostgreSQL, Authentication, Real-time)
- **Navigation**: Expo Router
- **Language**: TypeScript
- **UI**: React Native Components with custom styling

## 📋 Prerequisites

- Node.js (v18 or later)
- npm or yarn
- Expo CLI
- A Supabase account (for backend)

## 🚀 Getting Started

### Installation

1. Clone the repository:
```bash
git clone https://github.com/yourusername/pickup-ucf.git
cd pickup-ucf
```

2. Install dependencies:
```bash
cd app
npm install
```

3. Set up Supabase:
   - Create a new project at [supabase.com](https://supabase.com)
   - Run the SQL schema from `supabase-schema.sql` in your Supabase SQL editor
   - Get your Supabase URL and anon key

4. Configure environment variables:
   - Create a `.env` file in the `app` directory
   - Add your Supabase credentials:
   ```
   EXPO_PUBLIC_SUPABASE_URL=your_supabase_url
   EXPO_PUBLIC_SUPABASE_ANON_KEY=your_anon_key
   ```

5. Start the development server:
```bash
npm start
```

### Run on iOS/Android

- **iOS**: `npm run ios` (requires macOS with Xcode)
- **Android**: `npm run android` (requires Android Studio)

## 📱 App Structure

```
app/
├── app/                    # App screens and navigation
│   ├── index.tsx         # Entry point and auth flow
│   ├── main.tsx          # Main feed of sessions
│   ├── create.tsx        # Create new session
│   ├── profile.tsx       # User profile
│   └── session/          # Session details and chat
├── hooks/                # Custom React hooks
│   ├── useFeed.ts       # Fetch and manage sessions
│   └── useSession.ts    # Authentication state
├── lib/                  # Utilities and services
│   ├── supabase.ts      # Supabase client
│   └── title.ts          # Formatting utilities
├── constants/            # App constants
│   └── venues.ts        # UCF venue data
└── assets/               # Images and styles
```

## 🔐 Authentication

The app uses Supabase Auth with email/password. Only users with `@ucf.edu` email addresses can sign up and create sessions.

## 📊 Database Schema

The app uses PostgreSQL with the following main tables:
- `profiles` - User profiles and information
- `sessions` - Pickup sports sessions
- `session_members` - Participants in sessions
- `messages` - Chat messages in sessions

See `supabase-schema.sql` for the complete schema.

## 🎨 Design Philosophy

The app features a clean, UCF-themed design with:
- UCF Gold (#FFC904) as the primary accent color
- Intuitive navigation and user flow
- Responsive layouts for all screen sizes
- Smooth animations and transitions

## 🤝 Contributing

This is a UCF student project. If you're a UCF student and want to contribute:

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Submit a pull request

## 📝 License

MIT License - feel free to use this project for learning and development.

## 👨‍💻 Author

**Nurlan Mammadli** - UCF Student

## 🙏 Acknowledgments

- Built for the UCF Knight community
- Powered by [Expo](https://expo.dev/) and [Supabase](https://supabase.com/)

---

**Made by a UCF Knight**
