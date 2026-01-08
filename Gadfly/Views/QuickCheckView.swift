import SwiftUI
import CoreHaptics

struct QuickCheckView: View {
    let locationName: String
    let onComplete: () -> Void
    let onDismiss: () -> Void
    
    @ObservedObject private var service = QuickCheckService.shared
    @EnvironmentObject var appState: AppState
    
    @State private var walletChecked = false
    @State private var keysChecked = false
    @State private var phoneChecked = true
    @State private var showingMore = false
    @State private var allDone = false
    @State private var hapticEngine: CHHapticEngine?
    
    private var essentialsComplete: Bool {
        walletChecked && keysChecked && phoneChecked
    }
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            if allDone {
                doneView
            } else if showingMore {
                fullChecklistView
            } else {
                essentialsView
            }
        }
        .onAppear {
            prepareHaptics()
            announceCheck()
        }
    }
    
    private var essentialsView: some View {
        VStack(spacing: 0) {
            Spacer()
            
            VStack(spacing: 8) {
                Image(systemName: locationIcon)
                    .font(.system(size: 40))
                    .foregroundStyle(Color.themeAccent)
                
                Text("Leaving \(locationName)?")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundStyle(.white)
            }
            .padding(.bottom, 40)
            
            HStack(spacing: 20) {
                essentialButton(
                    icon: "creditcard.fill",
                    label: "Wallet",
                    isChecked: $walletChecked
                )
                
                essentialButton(
                    icon: "key.fill",
                    label: "Keys",
                    isChecked: $keysChecked
                )
                
                essentialButton(
                    icon: "iphone",
                    label: "Phone",
                    isChecked: $phoneChecked
                )
            }
            .padding(.horizontal, 20)
            
            Spacer()
            
            VStack(spacing: 16) {
                Button {
                    confirmAll()
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: essentialsComplete ? "checkmark.circle.fill" : "hand.thumbsup.fill")
                        Text(essentialsComplete ? "All Good!" : "Got 'em all!")
                    }
                    .font(.title2.bold())
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
                    .background(essentialsComplete ? Color.green : Color.themeAccent)
                    .cornerRadius(16)
                }
                
                HStack(spacing: 24) {
                    Button {
                        showingMore = true
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "plus.circle")
                            Text("More items")
                        }
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.6))
                    }
                    
                    Button {
                        onDismiss()
                    } label: {
                        Text("Not leaving")
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.4))
                    }
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 50)
        }
    }
    
    private func essentialButton(icon: String, label: String, isChecked: Binding<Bool>) -> some View {
        Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                isChecked.wrappedValue.toggle()
            }
            if isChecked.wrappedValue {
                playTapHaptic()
            }
        } label: {
            VStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(isChecked.wrappedValue ? Color.green : Color.white.opacity(0.1))
                        .frame(width: 90, height: 90)
                    
                    if isChecked.wrappedValue {
                        Image(systemName: "checkmark")
                            .font(.system(size: 40, weight: .bold))
                            .foregroundStyle(.white)
                    } else {
                        Image(systemName: icon)
                            .font(.system(size: 36))
                            .foregroundStyle(.white.opacity(0.8))
                    }
                }
                
                Text(label)
                    .font(.headline)
                    .foregroundStyle(isChecked.wrappedValue ? .green : .white.opacity(0.7))
            }
        }
        .buttonStyle(.plain)
    }
    
    private var fullChecklistView: some View {
        VStack(spacing: 0) {
            HStack {
                Button {
                    showingMore = false
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                        Text("Back")
                    }
                    .foregroundStyle(.white.opacity(0.6))
                }
                
                Spacer()
                
                Text("Full Checklist")
                    .font(.headline)
                    .foregroundStyle(.white)
                
                Spacer()
                
                Button {
                    onDismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.white.opacity(0.4))
                }
            }
            .padding()
            
            ScrollView {
                VStack(spacing: 12) {
                    ForEach(service.allItems) { item in
                        checklistRow(item: item)
                    }
                }
                .padding(.horizontal)
            }
            
            Button {
                withAnimation {
                    allDone = true
                }
                playSuccessHaptic()
                speakCompletion()
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    onComplete()
                }
            } label: {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                    Text("Done!")
                }
                .font(.title3.bold())
                .foregroundStyle(.black)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 18)
                .background(Color.green)
                .cornerRadius(14)
            }
            .padding()
        }
    }
    
    private func checklistRow(item: QuickCheckService.CheckItem) -> some View {
        let isChecked = service.isChecked(item.id)
        
        return Button {
            service.toggle(item.id)
            if !isChecked {
                playTapHaptic()
            }
        } label: {
            HStack(spacing: 16) {
                Image(systemName: item.icon)
                    .font(.title2)
                    .foregroundStyle(isChecked ? .green : .white.opacity(0.6))
                    .frame(width: 40)
                
                Text(item.name)
                    .font(.body)
                    .foregroundStyle(isChecked ? .green : .white)
                
                Spacer()
                
                Image(systemName: isChecked ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundStyle(isChecked ? .green : .white.opacity(0.3))
            }
            .padding(.vertical, 14)
            .padding(.horizontal, 16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isChecked ? Color.green.opacity(0.15) : Color.white.opacity(0.05))
            )
        }
        .buttonStyle(.plain)
    }
    
    private var doneView: some View {
        VStack(spacing: 20) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 100))
                .foregroundStyle(.green)
            
            Text("You're all set!")
                .font(.largeTitle.bold())
                .foregroundStyle(.white)
            
            Text("Have a great time!")
                .font(.title3)
                .foregroundStyle(.white.opacity(0.6))
        }
        .transition(.scale.combined(with: .opacity))
    }
    
    private var locationIcon: String {
        switch locationName.lowercased() {
        case let n where n.contains("gym"): return "dumbbell.fill"
        case let n where n.contains("work"): return "building.2.fill"
        case let n where n.contains("home"): return "house.fill"
        case let n where n.contains("school"): return "graduationcap.fill"
        default: return "location.fill"
        }
    }
    
    private func confirmAll() {
        walletChecked = true
        keysChecked = true
        phoneChecked = true
        
        playSuccessHaptic()
        speakCompletion()
        
        withAnimation(.spring(response: 0.4)) {
            allDone = true
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            onComplete()
        }
    }
    
    private func announceCheck() {
        let messages = [
            "Quick check! Wallet, keys, phone?",
            "Leaving \(locationName). Got everything?",
            "Wallet, keys, phone check!"
        ]
        Task { @MainActor in
            await AppDelegate.shared?.speakMessage(messages.randomElement()!)
        }
    }
    
    private func speakCompletion() {
        let messages = [
            "You're good to go!",
            "All set! Have a great time!",
            "Perfect! You've got everything!"
        ]
        Task { @MainActor in
            await AppDelegate.shared?.speakMessage(messages.randomElement()!)
        }
    }
    
    private func prepareHaptics() {
        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics else { return }
        do {
            hapticEngine = try CHHapticEngine()
            try hapticEngine?.start()
        } catch {
            print("Haptic engine error: \(error)")
        }
    }
    
    private func playTapHaptic() {
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
    }
    
    private func playSuccessHaptic() {
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
    }
}

#Preview {
    QuickCheckView(
        locationName: "Home",
        onComplete: {},
        onDismiss: {}
    )
    .environmentObject(AppState())
}
