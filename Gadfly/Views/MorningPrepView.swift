import SwiftUI

struct MorningPrepView: View {
    let onComplete: () -> Void
    let onSkip: () -> Void
    
    @ObservedObject private var service = MorningPrepService.shared
    @ObservedObject private var themeColors = ThemeColors.shared
    @EnvironmentObject var appState: AppState
    
    @State private var currentIndex = 0
    @State private var showingIntro = true
    @State private var showingAllDone = false
    @State private var showLocationInput: String? = nil
    @State private var locationText: String = ""
    
    private var activeItems: [MorningPrepService.PrepItem] {
        service.activeItems
    }
    
    private var currentItem: MorningPrepService.PrepItem? {
        guard currentIndex < activeItems.count else { return nil }
        return activeItems[currentIndex]
    }
    
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(hex: "1a2a1e"), Color(hex: "0f1a12")],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            
            VStack(spacing: 0) {
                if showingIntro {
                    introView
                } else if showingAllDone {
                    completionView
                } else if let item = currentItem {
                    checkItemView(for: item)
                } else {
                    noItemsView
                }
            }
        }
        .onAppear {
            service.resetProgress()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                speakIntro()
            }
        }
    }
    
    // MARK: - Intro View
    
    private var introView: some View {
        VStack(spacing: 24) {
            Spacer()
            
            VStack(spacing: 16) {
                Image(systemName: "sunrise.fill")
                    .font(.system(size: 80))
                    .foregroundStyle(.orange)
                
                Text("Ready to Head Out?")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundStyle(.white)
                
                Text("Let's make sure you have everything")
                    .font(.title3)
                    .foregroundStyle(.white.opacity(0.7))
                
                // Item count
                Text("\(activeItems.count) items to check")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.5))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.white.opacity(0.1))
                    .cornerRadius(12)
            }
            
            Spacer()
            
            // Action buttons
            VStack(spacing: 16) {
                Button {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        showingIntro = false
                    }
                    speakCurrentItem()
                } label: {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                        Text("Start Checklist")
                    }
                    .font(.title2.bold())
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
                    .background(Color.themeAccent)
                    .cornerRadius(16)
                }
                
                Button {
                    onSkip()
                } label: {
                    Text("Skip for now")
                        .font(.body)
                        .foregroundStyle(.white.opacity(0.6))
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 40)
        }
    }
    
    // MARK: - Check Item View
    
    private func checkItemView(for item: MorningPrepService.PrepItem) -> some View {
        VStack(spacing: 0) {
            // Header with progress
            HStack {
                Button {
                    onSkip()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.white.opacity(0.4))
                }
                
                Spacer()
                
                // Progress dots
                HStack(spacing: 4) {
                    ForEach(0..<activeItems.count, id: \.self) { index in
                        Circle()
                            .fill(index < currentIndex ? Color.green : (index == currentIndex ? themeColors.accent : Color.white.opacity(0.3)))
                            .frame(width: 8, height: 8)
                    }
                }
                
                Spacer()
                
                Text("\(currentIndex + 1)/\(activeItems.count)")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.5))
            }
            .padding()
            
            Spacer()
            
            // Main item display
            VStack(spacing: 24) {
                // Icon
                Image(systemName: item.icon)
                    .font(.system(size: 80))
                    .foregroundStyle(themeColors.accent)
                
                // Question
                Text(item.question)
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
                
                // Last known location (if available)
                if let location = service.itemLocations[item.id], !location.isEmpty {
                    HStack(spacing: 8) {
                        Image(systemName: "mappin")
                            .font(.caption)
                        Text("Last seen: \(location)")
                            .font(.subheadline)
                    }
                    .foregroundStyle(.white.opacity(0.5))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color.white.opacity(0.1))
                    .cornerRadius(12)
                }
            }
            
            Spacer()
            
            // Location input (if shown)
            if showLocationInput == item.id {
                VStack(spacing: 12) {
                    Text("Where did you last see it?")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.7))
                    
                    HStack(spacing: 8) {
                        TextField("e.g., On the kitchen counter", text: $locationText)
                            .textFieldStyle(.plain)
                            .padding(12)
                            .background(Color.white.opacity(0.1))
                            .cornerRadius(8)
                            .foregroundStyle(.white)
                        
                        Button {
                            if !locationText.isEmpty {
                                service.setLocation(for: item.id, location: locationText)
                            }
                            showLocationInput = nil
                            locationText = ""
                            proceedToNext()
                        } label: {
                            Text("OK")
                                .fontWeight(.bold)
                                .foregroundStyle(.black)
                                .padding(.horizontal, 20)
                                .padding(.vertical, 12)
                                .background(themeColors.accent)
                                .cornerRadius(8)
                        }
                    }
                    .padding(.horizontal, 24)
                }
                .padding(.bottom, 20)
                .transition(.opacity.combined(with: .move(edge: .bottom)))
            }
            
            // Action buttons
            VStack(spacing: 16) {
                HStack(spacing: 16) {
                    // YES button
                    Button {
                        service.markChecked(item.id)
                        proceedToNext()
                    } label: {
                        HStack {
                            Image(systemName: "checkmark")
                                .fontWeight(.bold)
                            Text("Yes!")
                        }
                        .font(.title2.bold())
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 20)
                        .background(Color.green)
                        .cornerRadius(16)
                    }
                    
                    // NO / Not Sure button
                    Button {
                        withAnimation(.spring(response: 0.3)) {
                            showLocationInput = item.id
                            locationText = service.itemLocations[item.id] ?? ""
                        }
                    } label: {
                        HStack {
                            Image(systemName: "questionmark")
                                .fontWeight(.bold)
                            Text("No")
                        }
                        .font(.title2.bold())
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 20)
                        .background(Color.orange)
                        .cornerRadius(16)
                    }
                }
                
                // Skip button
                Button {
                    proceedToNext()
                } label: {
                    Text("Skip this one")
                        .font(.body)
                        .foregroundStyle(.white.opacity(0.5))
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 40)
        }
    }
    
    // MARK: - Completion View
    
    private var completionView: some View {
        VStack(spacing: 24) {
            Spacer()
            
            VStack(spacing: 20) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 100))
                    .foregroundStyle(.green)
                
                Text("You're All Set!")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundStyle(.white)
                
                Text("Have a great day!")
                    .font(.title3)
                    .foregroundStyle(.white.opacity(0.7))
                
                // Stats
                let checked = service.checkedItems.count
                let total = activeItems.count
                Text("\(checked)/\(total) items confirmed")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.5))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.white.opacity(0.1))
                    .cornerRadius(12)
            }
            
            Spacer()
            
            Button {
                onComplete()
            } label: {
                Text("Done")
                    .font(.title2.bold())
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
                    .background(Color.themeAccent)
                    .cornerRadius(16)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 40)
        }
    }
    
    // MARK: - No Items View
    
    private var noItemsView: some View {
        VStack(spacing: 24) {
            Spacer()
            
            VStack(spacing: 16) {
                Image(systemName: "checklist")
                    .font(.system(size: 60))
                    .foregroundStyle(.white.opacity(0.4))
                
                Text("No items configured")
                    .font(.title2)
                    .foregroundStyle(.white.opacity(0.7))
                
                Text("Add items in Settings")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.5))
            }
            
            Spacer()
            
            Button {
                onSkip()
            } label: {
                Text("Got it")
                    .font(.title3.bold())
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color.themeAccent)
                    .cornerRadius(12)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 40)
        }
    }
    
    // MARK: - Actions
    
    private func proceedToNext() {
        if currentIndex < activeItems.count - 1 {
            withAnimation(.easeInOut(duration: 0.3)) {
                currentIndex += 1
            }
            speakCurrentItem()
        } else {
            withAnimation(.easeInOut(duration: 0.3)) {
                showingAllDone = true
            }
            speakCompletion()
        }
    }
    
    // MARK: - Speech
    
    private func speakIntro() {
        let message = getPersonalityIntro()
        Task { @MainActor in
            await AppDelegate.shared?.speakMessage(message)
        }
    }
    
    private func speakCurrentItem() {
        guard let item = currentItem else { return }
        Task { @MainActor in
            await AppDelegate.shared?.speakMessage(item.question)
        }
    }
    
    private func speakCompletion() {
        let message = getPersonalityCompletion()
        Task { @MainActor in
            await AppDelegate.shared?.speakMessage(message)
        }
    }
    
    // MARK: - Personality Messages
    
    private func getPersonalityIntro() -> String {
        let personality = appState.selectedPersonality
        
        switch personality {
        case .pemberton:
            return "Ah, heading out are we? Let's ensure you haven't forgotten anything important, shall we?"
        case .sergent:
            return "ATTENTION! Pre-departure checklist! We are NOT leaving without everything!"
        case .cheerleader:
            return "Yay! Getting ready to go! Let's make sure you have everything you need!"
        case .butler:
            return "If I may, before you depart, a brief review of your essentials?"
        case .coach:
            return "Alright champ! Pre-game checklist! Let's make sure you're ready to win the day!"
        case .zen:
            return "Before you venture forth, let us mindfully ensure you carry what you need."
        case .parent:
            return "Before you go, sweetie, let's make sure you have everything!"
        case .bestie:
            return "Wait wait wait! Quick check before you bounce - you got everything?"
        case .robot:
            return "Initiating pre-departure verification protocol. Stand by for checklist."
        case .therapist:
            return "Let's do a gentle check-in before you head out. Take your time."
        case .hypeFriend:
            return "HOLD UP! CHECKLIST TIME! WE ARE NOT FORGETTING STUFF TODAY!"
        case .chillBuddy:
            return "Hey, quick check before you go... no rush though."
        case .snarky:
            return "Oh, leaving? Let's see what you're about to forget this time."
        case .gamer:
            return "Equipment check before the quest! Don't leave the hub without your gear!"
        case .tiredParent:
            return "Before you go... did you... let me just check... you have everything?"
        case .sage:
            return "The prepared traveler carries their essentials. Let us verify yours."
        case .rebel:
            return "Quick check - make sure you have what you need to take on the world."
        case .trickster:
            return "You're DEFINITELY not forgetting anything today... or ARE you?"
        case .stoic:
            return "A moment of preparation prevents hours of frustration. Let us verify."
        case .pirate:
            return "Before we set sail! Inventory check, matey!"
        case .witch:
            return "One does not leave their dwelling without the proper ingredients for the day."
        }
    }
    
    private func getPersonalityCompletion() -> String {
        let personality = appState.selectedPersonality
        
        switch personality {
        case .pemberton:
            return "Excellent. You appear to be properly equipped. Off you go then."
        case .sergent:
            return "ALL SYSTEMS GO! You are cleared for departure! Move out!"
        case .cheerleader:
            return "Amazing! You've got everything! Go have an awesome day!"
        case .butler:
            return "Very good. You are fully prepared. Have a splendid day."
        case .coach:
            return "You're locked and loaded! Now go out there and crush it!"
        case .zen:
            return "You are prepared. Go forth with peace and purpose."
        case .parent:
            return "All set! Have a wonderful day, sweetie. Love you!"
        case .bestie:
            return "You're good to go! Text me later! Have fun!"
        case .robot:
            return "Verification complete. All systems nominal. Departure authorized."
        case .therapist:
            return "Wonderful. You're prepared. Remember to be kind to yourself today."
        case .hypeFriend:
            return "YOU'RE READY! GO BE AMAZING! YOU'VE GOT THIS!"
        case .chillBuddy:
            return "Cool, you're all set. Have a good one."
        case .snarky:
            return "Well, would you look at that. You actually have everything. I'm shocked."
        case .gamer:
            return "Inventory complete! Quest accepted! Go get those achievements!"
        case .tiredParent:
            return "Okay... you're good. Have a good day. Be safe."
        case .sage:
            return "You are prepared for the journey ahead. Go with wisdom."
        case .rebel:
            return "You're equipped. Now go change the world."
        case .trickster:
            return "Checklist complete! Unless... no, you're definitely ready. Probably."
        case .stoic:
            return "You have what you need. Use your time wisely."
        case .pirate:
            return "All cargo accounted for! Fair winds and following seas!"
        case .witch:
            return "The departure spell is complete. Safe travels, darling."
        }
    }
}

// MARK: - Preview

#Preview {
    MorningPrepView(
        onComplete: {},
        onSkip: {}
    )
    .environmentObject(AppState())
}
