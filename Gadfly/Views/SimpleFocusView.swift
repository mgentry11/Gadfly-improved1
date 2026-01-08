import SwiftUI
import EventKit

struct SimpleFocusView: View {
    @EnvironmentObject var appState: AppState
    @ObservedObject private var themeColors = ThemeColors.shared
    @StateObject private var calendarService = CalendarService()
    
    @State private var reminders: [EKReminder] = []
    @State private var isLoading = true
    @State private var showMoreOptions = false
    @State private var showAllTasks = false
    
    private var currentTask: EKReminder? {
        reminders
            .filter { !$0.isCompleted }
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
    
    private var remainingCount: Int {
        reminders.filter { !$0.isCompleted }.count - (currentTask != nil ? 1 : 0)
    }
    
    var body: some View {
        ZStack {
            themeColors.background.ignoresSafeArea()
            
            VStack(spacing: 0) {
                topBar
                
                Spacer()
                
                if isLoading {
                    ProgressView()
                        .tint(themeColors.accent)
                } else if let task = currentTask {
                    mainTaskView(task)
                } else {
                    allDoneView
                }
                
                Spacer()
                
                if currentTask != nil {
                    bottomBar
                }
            }
        }
        .sheet(isPresented: $showAllTasks) {
            TasksListView()
        }
        .task {
            _ = await calendarService.requestReminderAccess()
            await loadReminders()
        }
    }
    
    private var topBar: some View {
        HStack {
            if remainingCount > 0 {
                Button {
                    showAllTasks = true
                } label: {
                    Text("+\(remainingCount) more")
                        .font(.subheadline)
                        .foregroundStyle(themeColors.subtext)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Capsule().fill(themeColors.secondary))
                }
            }
            
            Spacer()
            
            Menu {
                Button { } label: { Label("Add Task", systemImage: "plus") }
                Button { showAllTasks = true } label: { Label("All Tasks", systemImage: "list.bullet") }
                Divider()
                Button { } label: { Label("Settings", systemImage: "gear") }
            } label: {
                Image(systemName: "ellipsis.circle")
                    .font(.title2)
                    .foregroundStyle(themeColors.subtext)
            }
        }
        .padding()
    }
    
    private func mainTaskView(_ task: EKReminder) -> some View {
        VStack(spacing: 24) {
            VStack(spacing: 16) {
                HStack(spacing: 8) {
                    if task.priority > 0 && task.priority <= 4 {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                    }
                    Text("YOUR TASK")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(themeColors.accent)
                        .tracking(1)
                }
                
                Text(task.title ?? "Untitled")
                    .font(.system(size: 26, weight: .bold))
                    .foregroundStyle(themeColors.text)
                    .multilineTextAlignment(.center)
                
                if let dueDate = task.dueDateComponents?.date {
                    Text(timeRemaining(until: dueDate))
                        .font(.body.weight(.medium))
                        .foregroundStyle(themeColors.subtext)
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
            
            doneButton(task)
            
            if showMoreOptions {
                moreOptionsView
            } else {
                Button {
                    withAnimation(.spring(response: 0.3)) {
                        showMoreOptions = true
                    }
                } label: {
                    Text("Need help?")
                        .font(.subheadline)
                        .foregroundStyle(themeColors.accent)
                }
            }
        }
        .padding()
    }
    
    private func doneButton(_ task: EKReminder) -> some View {
        Button {
            Task { await completeTask(task) }
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "checkmark")
                    .font(.title2.bold())
                Text("Done!")
                    .font(.title2.bold())
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 70)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color.green)
            )
        }
        .padding(.horizontal, 40)
    }
    
    private var moreOptionsView: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                optionButton(icon: "lightbulb", label: "How?", color: .blue) { }
                optionButton(icon: "arrow.triangle.branch", label: "Split", color: .purple) { }
                optionButton(icon: "arrow.right", label: "Later", color: .orange) { }
                optionButton(icon: "xmark", label: "Skip", color: .gray) { }
            }
            
            Button {
                withAnimation { showMoreOptions = false }
            } label: {
                Text("Hide options")
                    .font(.caption)
                    .foregroundStyle(themeColors.subtext)
            }
        }
        .transition(.opacity.combined(with: .move(edge: .bottom)))
    }
    
    private func optionButton(icon: String, label: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundStyle(color)
                Text(label)
                    .font(.caption2)
                    .foregroundStyle(themeColors.subtext)
            }
            .frame(width: 60, height: 60)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(themeColors.secondary)
            )
        }
    }
    
    private var allDoneView: some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 80))
                .foregroundStyle(.green)
            
            Text("All done!")
                .font(.largeTitle.bold())
                .foregroundStyle(themeColors.text)
            
            Text("Nothing else right now")
                .font(.subheadline)
                .foregroundStyle(themeColors.subtext)
        }
    }
    
    private var bottomBar: some View {
        HStack {
            Button { } label: {
                Image(systemName: "mic.fill")
                    .font(.title2)
                    .foregroundStyle(themeColors.accent)
                    .frame(width: 56, height: 56)
                    .background(Circle().fill(themeColors.secondary))
            }
            
            Spacer()
        }
        .padding()
    }
    
    private func timeRemaining(until date: Date) -> String {
        let now = Date()
        let interval = date.timeIntervalSince(now)
        
        if interval < 0 { return "Ready when you are" }
        if interval < 3600 { return "\(Int(interval / 60)) min left" }
        if interval < 86400 { return "\(Int(interval / 3600)) hours left" }
        return "\(Int(interval / 86400)) days left"
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
            await loadReminders()
            CelebrationService.shared.celebrate(level: .standard, taskTitle: task.title ?? "Task")
        } catch {
            print("Error completing task: \(error)")
        }
    }
}

#Preview {
    SimpleFocusView()
        .environmentObject(AppState())
}
