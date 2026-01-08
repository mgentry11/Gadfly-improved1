import SwiftUI
import EventKit

struct GuidedHomeView: View {
    @EnvironmentObject var appState: AppState
    @ObservedObject private var themeColors = ThemeColors.shared
    @StateObject private var calendarService = CalendarService()
    @ObservedObject private var energyService = EnergyService.shared
    
    @State private var reminders: [EKReminder] = []
    @State private var isLoading = true
    @State private var guidanceMessage = ""
    @State private var showingHelp = false
    @State private var showingHowSheet = false
    @State private var showingAddTask = false
    @State private var skippedTaskIds: Set<String> = []
    @State private var proactiveSuggestion: ProactiveSuggestion?
    
    struct ProactiveSuggestion: Identifiable {
        let id = UUID()
        let icon: String
        let color: Color
        let title: String
        let subtitle: String
        let action: SuggestionAction
        
        enum SuggestionAction {
            case morningCheckin
            case eveningCheckin
            case takeBreak
            case drinkWater
            case stretch
            case reviewTasks
        }
    }
    
    private var currentTask: EKReminder? {
        reminders
            .filter { !$0.isCompleted }
            .filter { reminder in
                !skippedTaskIds.contains(reminder.calendarItemIdentifier)
            }
            .sorted { r1, r2 in
                let p1 = r1.priority == 0 ? 5 : r1.priority
                let p2 = r2.priority == 0 ? 5 : r2.priority
                if p1 != p2 { return p1 < p2 }
                let d1 = r1.dueDateComponents?.date ?? .distantFuture
                let d2 = r2.dueDateComponents?.date ?? .distantFuture
                return d1 < d2
            }
            .first
    }
    
    private var timeOfDay: TimeOfDay {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<12: return .morning
        case 12..<17: return .afternoon
        case 17..<21: return .evening
        default: return .night
        }
    }
    
    enum TimeOfDay {
        case morning, afternoon, evening, night
        
        var greeting: String {
            switch self {
            case .morning: return "Good morning"
            case .afternoon: return "Good afternoon"
            case .evening: return "Good evening"
            case .night: return "Hey there"
            }
        }
        
        var icon: String {
            switch self {
            case .morning: return "sunrise.fill"
            case .afternoon: return "sun.max.fill"
            case .evening: return "sunset.fill"
            case .night: return "moon.fill"
            }
        }
        
        var color: Color {
            switch self {
            case .morning: return .orange
            case .afternoon: return .yellow
            case .evening: return .purple
            case .night: return .indigo
            }
        }
    }
    
    var body: some View {
        ZStack {
            themeColors.background.ignoresSafeArea()
            
            VStack(spacing: 0) {
                if energyService.showCheckInPrompt {
                    energyCheckInBanner
                }
                
                if isLoading {
                    loadingView
                } else if let task = currentTask {
                    guidedTaskView(task)
                } else {
                    nothingToDoView
                }
            }
        }
        .task {
            _ = await calendarService.requestReminderAccess()
            await loadReminders()
            generateGuidance()
            generateProactiveSuggestion()
            energyService.checkIfNeedsCheckIn()
        }
    }
    
    private var energyCheckInBanner: some View {
        VStack(spacing: 12) {
            Text("How's your energy right now?")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(themeColors.text)
            
            HStack(spacing: 12) {
                energyButton(.low, emoji: "🔋", label: "Low")
                energyButton(.medium, emoji: "⚡", label: "Normal")
                energyButton(.high, emoji: "🚀", label: "High")
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(themeColors.secondary)
        )
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }
    
    private func energyButton(_ level: EnergyService.EnergyLevel, emoji: String, label: String) -> some View {
        Button {
            withAnimation(.spring(response: 0.3)) {
                energyService.setEnergy(level)
            }
            Task {
                let message = level == .low 
                    ? "Got it. I'll suggest easier tasks today." 
                    : level == .high 
                        ? "Awesome! Let's tackle something challenging!" 
                        : "Sounds good. Here's what's next."
                await AppDelegate.shared?.speakMessage(message)
            }
        } label: {
            VStack(spacing: 4) {
                Text(emoji)
                    .font(.title2)
                Text(label)
                    .font(.caption.weight(.medium))
            }
            .frame(maxWidth: .infinity)
            .frame(height: 70)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(level.color.opacity(0.15))
            )
            .foregroundStyle(level.color)
        }
    }
    
    private var loadingView: some View {
        VStack(spacing: 20) {
            ProgressView()
                .tint(themeColors.accent)
            Text("Getting your day ready...")
                .font(.subheadline)
                .foregroundStyle(themeColors.subtext)
        }
    }
    
    private func guidedTaskView(_ task: EKReminder) -> some View {
        VStack(spacing: 0) {
            if let suggestion = proactiveSuggestion {
                proactiveBanner(suggestion)
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
            }
            
            Spacer()
            
            VStack(spacing: 16) {
                Text(guidanceMessage)
                    .font(.title3)
                    .foregroundStyle(themeColors.subtext)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                
                VStack(spacing: 16) {
                    HStack(spacing: 8) {
                        Image(systemName: timeOfDay.icon)
                            .font(.title3)
                            .foregroundStyle(timeOfDay.color)
                        Text("YOUR TASK")
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(themeColors.accent)
                            .tracking(1)
                    }
                    
                    Text(task.title ?? "Your next task")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundStyle(themeColors.text)
                        .multilineTextAlignment(.center)
                    
                    if let dueDate = task.dueDateComponents?.date {
                        timeHint(for: dueDate)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
                .padding(.horizontal, 20)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(themeColors.secondary)
                )
                .padding(.horizontal, 20)
            }
            
            Spacer()
            
            VStack(spacing: 12) {
                Button {
                    Task { await completeTask(task) }
                } label: {
                    Text("Done")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 64)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color.green)
                        )
                }
                
                HStack(spacing: 12) {
                    Button {
                        Task { await pushToLater(task) }
                    } label: {
                        Text("Later")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                            .background(
                                RoundedRectangle(cornerRadius: 14)
                                    .fill(Color.orange)
                            )
                    }
                    
                    Button {
                        skipTask(task)
                    } label: {
                        Text("Skip")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                            .background(
                                RoundedRectangle(cornerRadius: 14)
                                    .fill(Color.gray)
                            )
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 32)
        }
    }
    
    private func timeHint(for date: Date) -> some View {
        let remaining = date.timeIntervalSince(Date())
        let text: String
        let color: Color
        
        if remaining < 0 {
            text = "This one's been waiting - let's do it together"
            color = .red
        } else if remaining < 1800 {
            text = "Due very soon - you've got this!"
            color = .orange
        } else if remaining < 3600 {
            text = "Due in about an hour"
            color = .yellow
        } else {
            text = "You have time, but let's get it done"
            color = themeColors.subtext
        }
        
        return Text(text)
            .font(.subheadline)
            .foregroundStyle(color)
    }
    
    private func helpOptions(for task: EKReminder) -> some View {
        HStack(spacing: 12) {
            helpButton(icon: "lightbulb.fill", label: "How?", color: .blue) {
                showingHowSheet = true
            }
            
            helpButton(icon: "clock.arrow.circlepath", label: "Later", color: .orange) {
                Task { await pushToLater(task) }
            }
            
            helpButton(icon: "forward.fill", label: "Skip", color: .gray) {
                skipTask(task)
            }
        }
        .transition(.opacity.combined(with: .scale(scale: 0.9)))
        .sheet(isPresented: $showingHowSheet) {
            HowToApproachSheet(task: task)
                .presentationDetents([.medium])
        }
    }
    
    private func pushToLater(_ task: EKReminder) async {
        let oneHourFromNow = Date().addingTimeInterval(3600)
        task.dueDateComponents = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: oneHourFromNow)
        
        do {
            try calendarService.store.save(task, commit: true)
            await loadReminders()
            generateGuidance()
            await AppDelegate.shared?.speakMessage("Okay, I'll remind you about this in an hour.")
        } catch {
            print("Error pushing task: \(error)")
        }
        
        withAnimation(.spring(response: 0.3)) {
            showingHelp = false
        }
    }
    
    private func skipTask(_ task: EKReminder) {
        let taskId = task.calendarItemIdentifier
        
        withAnimation(.spring(response: 0.3)) {
            skippedTaskIds.insert(taskId)
            showingHelp = false
        }
        generateGuidance()
        
        Task {
            await AppDelegate.shared?.speakMessage("Skipped. Here's what's next.")
        }
    }
    
    private func helpButton(icon: String, label: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundStyle(color)
                Text(label)
                    .font(.caption)
                    .foregroundStyle(themeColors.subtext)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 70)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(themeColors.secondary)
            )
        }
    }
    
    private func proactiveBanner(_ suggestion: ProactiveSuggestion) -> some View {
        Button {
            handleSuggestionAction(suggestion.action)
        } label: {
            HStack(spacing: 12) {
                Image(systemName: suggestion.icon)
                    .font(.title3)
                    .foregroundStyle(suggestion.color)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(suggestion.title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(themeColors.text)
                    Text(suggestion.subtitle)
                        .font(.caption)
                        .foregroundStyle(themeColors.subtext)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(themeColors.subtext.opacity(0.5))
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(suggestion.color.opacity(0.1))
            )
        }
        .buttonStyle(.plain)
    }
    
    private func handleSuggestionAction(_ action: ProactiveSuggestion.SuggestionAction) {
        switch action {
        case .morningCheckin:
            appState.triggerMorningChecklist = true
        case .eveningCheckin:
            appState.triggerEveningChecklist = true
        case .takeBreak:
            appState.startBreakMode(durationMinutes: 5)
            Task {
                await AppDelegate.shared?.speakMessage("Taking a 5 minute break. You've earned it!")
            }
        case .drinkWater:
            Task {
                await AppDelegate.shared?.speakMessage("Good call! Staying hydrated helps you focus.")
            }
            withAnimation { proactiveSuggestion = nil }
        case .stretch:
            Task {
                await AppDelegate.shared?.speakMessage("Time to stretch! Roll your shoulders, stretch your neck.")
            }
            withAnimation { proactiveSuggestion = nil }
        case .reviewTasks:
            appState.selectedTab = 2
        }
    }
    
    private func generateProactiveSuggestion() {
        let hour = Calendar.current.component(.hour, from: Date())
        let completedCount = reminders.filter { $0.isCompleted }.count
        let pendingCount = reminders.filter { !$0.isCompleted }.count
        
        if hour >= 6 && hour < 10 && !appState.triggerMorningChecklist {
            proactiveSuggestion = ProactiveSuggestion(
                icon: "sunrise.fill",
                color: .orange,
                title: "Start your morning right",
                subtitle: "Quick check-in to set intentions",
                action: .morningCheckin
            )
        } else if hour >= 20 && hour < 23 {
            proactiveSuggestion = ProactiveSuggestion(
                icon: "moon.stars.fill",
                color: .indigo,
                title: "Wind down for the night",
                subtitle: "Evening reflection & tomorrow prep",
                action: .eveningCheckin
            )
        } else if completedCount >= 3 && completedCount % 3 == 0 {
            proactiveSuggestion = ProactiveSuggestion(
                icon: "cup.and.saucer.fill",
                color: .brown,
                title: "You've completed \(completedCount) tasks!",
                subtitle: "Take a quick break?",
                action: .takeBreak
            )
        } else if hour == 10 || hour == 14 || hour == 16 {
            proactiveSuggestion = ProactiveSuggestion(
                icon: "drop.fill",
                color: .cyan,
                title: "Hydration check",
                subtitle: "Have you had water recently?",
                action: .drinkWater
            )
        } else if pendingCount == 0 && hour >= 17 {
            proactiveSuggestion = ProactiveSuggestion(
                icon: "checkmark.seal.fill",
                color: .green,
                title: "Great job today!",
                subtitle: "All tasks complete - enjoy your evening",
                action: .eveningCheckin
            )
        } else {
            proactiveSuggestion = nil
        }
    }
    
    private var nothingToDoView: some View {
        VStack(spacing: 24) {
            Spacer()
            
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 80))
                .foregroundStyle(.green)
            
            Text("You're all caught up!")
                .font(.title.bold())
                .foregroundStyle(themeColors.text)
            
            Text(relaxMessage)
                .font(.body)
                .foregroundStyle(themeColors.subtext)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            
            Spacer()
            
            Button {
                showingAddTask = true
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "plus")
                        .font(.title3.weight(.semibold))
                    Text("Add Task")
                        .font(.system(size: 18, weight: .semibold))
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(themeColors.accent)
                )
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 32)
            .sheet(isPresented: $showingAddTask) {
                QuickAddTaskSheet(onTaskAdded: {
                    Task { await loadReminders() }
                })
                .presentationDetents([.medium])
            }
        }
    }
    
    private var relaxMessage: String {
        switch timeOfDay {
        case .morning: return "Great start to the day! Take a moment to breathe."
        case .afternoon: return "Nice work! Enjoy a break or add something new."
        case .evening: return "Wonderful job today. Time to wind down."
        case .night: return "All done! Get some rest."
        }
    }
    
    private func generateGuidance() {
        let messages: [String]
        
        switch timeOfDay {
        case .morning:
            messages = [
                "Let's start your day with this:",
                "First thing on your plate:",
                "Good morning! Here's what's up:"
            ]
        case .afternoon:
            messages = [
                "Here's what needs your attention:",
                "Let's keep the momentum going:",
                "Next up for you:"
            ]
        case .evening:
            messages = [
                "Let's wrap up with this:",
                "One more thing for today:",
                "Before you wind down:"
            ]
        case .night:
            messages = [
                "If you're still working:",
                "Here's what's waiting:",
                "Still going? Here's next:"
            ]
        }
        
        guidanceMessage = messages.randomElement() ?? "Here's your next task:"
    }
    
    private func loadReminders() async {
        isLoading = true
        reminders = await calendarService.fetchReminders()
        isLoading = false
    }
    
    private func completeTask(_ task: EKReminder) async {
        task.isCompleted = true
        do {
            try calendarService.store.save(task, commit: true)
            CelebrationService.shared.celebrate(level: .standard, taskTitle: task.title ?? "Task")
            await loadReminders()
            generateGuidance()
            
            await AppDelegate.shared?.speakMessage(completionMessage)
        } catch {
            print("Error completing task: \(error)")
        }
    }
    
    private var completionMessage: String {
        let messages = [
            "Nice! What's next?",
            "Done! Keep it going!",
            "Great job! Here's the next one.",
            "Awesome! Moving on.",
            "Checked off! Let's continue."
        ]
        return messages.randomElement() ?? "Done!"
    }
}

struct HowToApproachSheet: View {
    let task: EKReminder
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var themeColors = ThemeColors.shared
    
    private var taskTitle: String {
        task.title ?? "this task"
    }
    
    private var suggestions: [String] {
        [
            "Break it into smaller steps",
            "Set a 5-minute timer and just start",
            "Do the easiest part first",
            "Remove distractions - phone away, notifications off",
            "Tell yourself: 'I'll just do it for 2 minutes'"
        ]
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("Struggling with '\(taskTitle)'?")
                        .font(.title2.bold())
                        .foregroundStyle(themeColors.text)
                    
                    Text("Here are some ways to get started:")
                        .font(.subheadline)
                        .foregroundStyle(themeColors.subtext)
                    
                    ForEach(suggestions, id: \.self) { suggestion in
                        HStack(alignment: .top, spacing: 12) {
                            Image(systemName: "lightbulb.fill")
                                .foregroundStyle(.yellow)
                                .font(.body)
                            Text(suggestion)
                                .font(.body)
                                .foregroundStyle(themeColors.text)
                        }
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(themeColors.secondary)
                        )
                    }
                }
                .padding()
            }
            .background(themeColors.background.ignoresSafeArea())
            .navigationTitle("Need Help?")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Got it") { dismiss() }
                }
            }
        }
    }
}

struct QuickAddTaskSheet: View {
    let onTaskAdded: () -> Void
    
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var themeColors = ThemeColors.shared
    @StateObject private var calendarService = CalendarService()
    
    @State private var taskTitle = ""
    @State private var isSaving = false
    @FocusState private var isFocused: Bool
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                TextField("What do you need to do?", text: $taskTitle)
                    .font(.title3)
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(themeColors.secondary)
                    )
                    .focused($isFocused)
                
                Spacer()
                
                Button {
                    Task { await saveTask() }
                } label: {
                    if isSaving {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Text("Add Task")
                            .font(.headline)
                    }
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(taskTitle.isEmpty ? Color.gray : Color.green)
                )
                .disabled(taskTitle.isEmpty || isSaving)
            }
            .padding()
            .background(themeColors.background.ignoresSafeArea())
            .navigationTitle("Quick Add")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .onAppear {
                isFocused = true
            }
        }
    }
    
    private func saveTask() async {
        guard !taskTitle.isEmpty else { return }
        isSaving = true
        
        let granted = await calendarService.requestReminderAccess()
        guard granted else {
            isSaving = false
            return
        }
        
        let reminder = EKReminder(eventStore: calendarService.store)
        reminder.title = taskTitle
        reminder.calendar = calendarService.store.defaultCalendarForNewReminders()
        
        do {
            try calendarService.store.save(reminder, commit: true)
            onTaskAdded()
            dismiss()
        } catch {
            print("Error saving reminder: \(error)")
        }
        
        isSaving = false
    }
}

#Preview {
    GuidedHomeView()
        .environmentObject(AppState())
}
