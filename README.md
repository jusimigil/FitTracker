**FitTracker**: The Intelligent Body Recomp Assistant
FitTracker is a smart coaching companion built with SwiftUI and HealthKit. It uses on-device statistical analysis to optimize body recomposition, ensuring progressive overload while preventing burnout through recovery-based autoregulation.

**Key Features**
🧠 _Advanced Recomp Engine (Machine Learning)_

Unlike standard trackers, FitTracker analyzes your performance trends using Linear Regression to provide real-time advice.

Strength Velocity: Calculates the slope of your 1RM history to detect rapid gains, steady climbs, or regression.

Training Density: Analyzes volume-per-minute to detect "junk volume" vs. high-intensity sessions.

Weak Link Detector: Automatically identifies lagging muscle groups based on weekly set volume.

Symmetry Analysis: monitors Upper vs. Lower body volume balance.

🔋 _Smart Recovery System_

Daily Check-In: A morning popup asks how you feel.

Autoregulation: The app adjusts daily targets based on your recovery score.

Low Recovery: Suggests active recovery/stretching.

High Recovery: Pushes for hypertrophy and volume overload.

🎵 _Music Journal & "Time Capsule"_

Workout Anthems: Tag specific songs to your workouts using the iTunes API to remember what hyped you up.

Memory Lane: The "History" tab surfaces past workouts, photos, and notes to keep you motivated.

📍 _Gym Mapping_

Location Clustering: Automatically groups workout sessions by GPS location to visualize your "Gym History" on a map.

⚡ _UX Enhancements_

Smart Autofill: When starting an exercise, the app pre-fills the weight and reps based on your last completed session or history.

Memory Optimization: Custom image downsampling pipeline to handle high-res progress photos without memory spikes.

🛠 _Technical Architecture_

The app follows a clean MVVM (Model-View-ViewModel) architecture with a focus on data persistence and privacy.


**Core Components**

DataManager: Handles JSON persistence for workouts, exercises, and body metrics. Includes backup/restore functionality.

RecompManager: The "Brain" of the app. Contains the math engine (Linear Regression) and logic for weekly volume targets (Fat Loss vs. Muscle Gain modes).

HealthManager: Manages HealthKit integration to auto-sync Heart Rate, Active Energy, and Runs/Swims from Apple Watch.
    
**Getting Started**

Prerequisites

Xcode 15+

iOS 17.0+

An Apple Developer Account (required for HealthKit capabilities)


**Installation**

Clone the repo:

git clone https://github.com/yourusername/fittracker.git

Open in Xcode: Double-click FitTracker.xcodeproj

Configure Signing:

Click on the Project root in the navigator.

Go to Signing & Capabilities.

Select your generic Development Team.

Note: Ensure HealthKit is added as a capability.

Run: Select your target simulator (e.g., iPhone 15 Pro) and hit Cmd + R.


**Permissions & Privacy**

FitTracker requests the following permissions to function fully:

HealthKit: To read Heart Rate and sync Runs/Swims.

Location: To cluster workouts by Gym location on the map.

Media Library: To control music playback and tag songs.

Notifications: To alert you when rest timers finish.

All data is stored locally on the device in JSON format. No data is sent to external servers.

