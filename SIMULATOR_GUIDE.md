# Running AntiEmoPet in the Xcode Simulator

Follow the steps below to boot the SunnyPet MVP inside Xcode's iOS Simulator.

1. **Install prerequisites**
   - Xcode 16 or later (tested with Xcode 16 beta 4).
   - iOS 17 SDK and the "iPhone 15 Pro" or newer simulator runtime.
   - Ensure "SwiftData" is enabled for the developer account (Xcode ▸ Settings ▸ Platforms ▸ iOS).

2. **Clone the repository**
   ```bash
   git clone https://github.com/<your-org>/Anti-Emo-App.git
   cd Anti-Emo-App
   ```

3. **Open the project**
   - Double-click `AntiEmoPet.xcodeproj`, or run `xed AntiEmoPet.xcodeproj` from Terminal.

4. **Select the run destination**
   - In the Xcode toolbar, set the active scheme to **AntiEmoPet**.
   - Choose a simulator such as **iPhone 15 Pro (iOS 17.5)** from the device list.

5. **Build once to warm the SwiftData model**
   - Press **⌘B** to trigger a build.
   - Resolve any first-run prompts (e.g., enable developer mode) that Xcode may present.

6. **Launch the simulator**
   - Click the **Run** button (**⌘R**). Xcode will compile and boot the chosen simulator.
   - The Sunny onboarding flow should appear on first launch. Complete the nickname + region step to unlock the main tabs.

7. **Rerun quickly after code changes**
   - Use **Shift+⌘K** to clean derived data if SwiftData schema errors appear.
   - When switching simulators, reset the runtime (Simulator ▸ Erase All Content and Settings…) to clear persisted SwiftData state.

8. **Run unit tests from Xcode**
   - Press **⌘U** to execute the `AntiEmoPetTests` suite in the currently selected simulator.
   - Alternatively, run from Terminal:
     ```bash
     xcodebuild -project AntiEmoPet.xcodeproj \
       -scheme AntiEmoPet \
       -destination 'platform=iOS Simulator,name=iPhone 15 Pro,OS=17.5' test
     ```

9. **Troubleshooting tips**
   - If seeding fails, stop the run, erase simulator content, and launch again to rebuild the SwiftData store.
   - Ensure Rosetta is installed if running on Apple Silicon and the simulator fails to boot legacy runtimes.
   - Verify the build target is **AntiEmoPet** (not the tests bundle) before hitting **⌘R**.
