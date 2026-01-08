import SwiftUI

enum HelpMode: String, CaseIterable, Identifiable {
    case gentle = "gentle"
    case balanced = "balanced"
    case persistent = "persistent"
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .gentle: return "Gentle"
        case .balanced: return "Balanced"
        case .persistent: return "Persistent"
        }
    }
    
    var description: String {
        switch self {
        case .gentle: return "Soft reminders"
        case .balanced: return "Regular check-ins"
        case .persistent: return "Won't let you forget"
        }
    }
    
    var icon: String {
        switch self {
        case .gentle: return "leaf.fill"
        case .balanced: return "circle.circle"
        case .persistent: return "bell.badge.fill"
        }
    }
    
    var color: Color {
        switch self {
        case .gentle: return .green
        case .balanced: return .blue
        case .persistent: return .orange
        }
    }
}

enum SmartPreset: String, CaseIterable, Identifiable {
    case justStarting = "just_starting"
    case needsStructure = "needs_structure"
    case hyperfocuser = "hyperfocuser"
    case workMode = "work_mode"
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .justStarting: return "Just Getting Started"
        case .needsStructure: return "I Need Structure"
        case .hyperfocuser: return "I Hyperfocus"
        case .workMode: return "Work/School Mode"
        }
    }
    
    var description: String {
        switch self {
        case .justStarting: return "Gentle guidance, minimal notifications"
        case .needsStructure: return "Regular check-ins, morning & evening routines"
        case .hyperfocuser: return "Breaks & stretch reminders, time awareness"
        case .workMode: return "Focus sessions, deadline-driven, minimal interruption"
        }
    }
    
    var icon: String {
        switch self {
        case .justStarting: return "sparkles"
        case .needsStructure: return "calendar.badge.clock"
        case .hyperfocuser: return "timer"
        case .workMode: return "briefcase.fill"
        }
    }
    
    var color: Color {
        switch self {
        case .justStarting: return .mint
        case .needsStructure: return .blue
        case .hyperfocuser: return .purple
        case .workMode: return .orange
        }
    }
}

struct SimpleSettingsView: View {
    @EnvironmentObject var appState: AppState
    @ObservedObject private var themeColors = ThemeColors.shared
    @AppStorage("help_mode") private var helpMode: String = HelpMode.balanced.rawValue
    @AppStorage("sounds_enabled") private var soundsEnabled: Bool = true
    @AppStorage("haptics_enabled") private var hapticsEnabled: Bool = true
    @AppStorage("celebrations_enabled") private var celebrationsEnabled: Bool = true
    @AppStorage("is_power_user") private var isPowerUser: Bool = false
    @AppStorage("has_chosen_preset") private var hasChosenPreset: Bool = false
    @AppStorage("selected_preset") private var selectedPreset: String = ""
    @State private var showAdvanced = false
    @State private var selectedVibe: VoiceVibe = .friendly
    
    private var currentHelpMode: HelpMode {
        HelpMode(rawValue: helpMode) ?? .balanced
    }
    
    private var currentPreset: SmartPreset? {
        SmartPreset(rawValue: selectedPreset)
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    if !hasChosenPreset {
                        smartPresetSection
                    } else {
                        currentPresetBadge
                        helpModeCards
                    }
                    themeSection
                    accessibilitySection
                    quickTogglesRow
                    if isPowerUser { advancedSection }
                    powerUserToggle
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            .background(Color.themeBackground)
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
    
    private var smartPresetSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text("What describes you best?")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.themeText)
                Text("We'll set everything up for you")
                    .font(.caption)
                    .foregroundStyle(Color.themeSubtext)
            }
            
            VStack(spacing: 8) {
                ForEach(SmartPreset.allCases) { preset in
                    smartPresetCard(preset)
                }
            }
        }
    }
    
    private func smartPresetCard(_ preset: SmartPreset) -> some View {
        Button {
            applySmartPreset(preset)
        } label: {
            HStack(spacing: 12) {
                Image(systemName: preset.icon)
                    .font(.body)
                    .foregroundStyle(preset.color)
                    .frame(width: 32, height: 32)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(preset.color.opacity(0.15))
                    )
                
                VStack(alignment: .leading, spacing: 1) {
                    Text(preset.displayName)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(Color.themeText)
                    Text(preset.description)
                        .font(.caption2)
                        .foregroundStyle(Color.themeSubtext)
                        .lineLimit(1)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption2)
                    .foregroundStyle(Color.themeSubtext.opacity(0.5))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.themeSecondary)
            )
        }
        .buttonStyle(.plain)
    }
    
    private var currentPresetBadge: some View {
        Group {
            if let preset = currentPreset {
                Button {
                    withAnimation { hasChosenPreset = false }
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: preset.icon)
                            .foregroundStyle(preset.color)
                        Text(preset.displayName)
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(Color.themeText)
                        Spacer()
                        Text("Change")
                            .font(.caption)
                            .foregroundStyle(Color.themeAccent)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(preset.color.opacity(0.1))
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }
    
    private func applySmartPreset(_ preset: SmartPreset) {
        selectedPreset = preset.rawValue
        hasChosenPreset = true
        
        switch preset {
        case .justStarting:
            helpMode = HelpMode.gentle.rawValue
            NaggingLevelService.shared.naggingLevel = .gentle
            appState.dailyCheckInsEnabled = false
            appState.morningBriefingEnabled = false
            soundsEnabled = true
            hapticsEnabled = true
            celebrationsEnabled = true
            appState.isSimpleMode = true
            
        case .needsStructure:
            helpMode = HelpMode.balanced.rawValue
            NaggingLevelService.shared.naggingLevel = .moderate
            appState.dailyCheckInsEnabled = true
            appState.morningBriefingEnabled = true
            appState.dailyCheckInTimes = ["09:00", "12:00", "17:00"]
            soundsEnabled = true
            hapticsEnabled = true
            celebrationsEnabled = true
            appState.isSimpleMode = true
            
        case .hyperfocuser:
            helpMode = HelpMode.balanced.rawValue
            NaggingLevelService.shared.naggingLevel = .moderate
            appState.dailyCheckInsEnabled = true
            appState.focusCheckInMinutes = 25
            appState.rewardBreaksEnabled = true
            appState.rewardBreakDuration = 5
            appState.autoSuggestBreaks = true
            soundsEnabled = true
            hapticsEnabled = true
            celebrationsEnabled = true
            appState.isSimpleMode = false
            
        case .workMode:
            helpMode = HelpMode.persistent.rawValue
            NaggingLevelService.shared.naggingLevel = .persistent
            appState.dailyCheckInsEnabled = true
            appState.morningBriefingEnabled = true
            appState.dailyCheckInTimes = ["09:00", "14:00"]
            appState.nagIntervalMinutes = 10
            soundsEnabled = false
            hapticsEnabled = true
            celebrationsEnabled = false
            appState.isSimpleMode = false
        }
        
        Task {
            await AppDelegate.shared?.speakMessage("Perfect! I've set everything up for you.")
        }
    }
    
    private var helpModeCards: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("How much help?")
                .font(.caption.weight(.medium))
                .foregroundStyle(Color.themeSubtext)
            
            HStack(spacing: 8) {
                ForEach(HelpMode.allCases) { mode in
                    helpModeCard(mode)
                }
            }
        }
    }
    
    private func helpModeCard(_ mode: HelpMode) -> some View {
        let isSelected = currentHelpMode == mode
        
        return Button {
            helpMode = mode.rawValue
            applyHelpMode(mode)
        } label: {
            VStack(spacing: 6) {
                Image(systemName: mode.icon)
                    .font(.body)
                    .foregroundStyle(isSelected ? .white : mode.color)
                
                Text(mode.displayName)
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(isSelected ? .white : Color.themeText)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 60)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? mode.color : Color.themeSecondary)
            )
        }
        .buttonStyle(.plain)
    }
    
    private var themeSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Color")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(Color.themeSubtext)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(quickThemes, id: \.self) { theme in
                        themeCircle(theme)
                    }
                    
                    if !isPowerUser {
                        Button {
                            isPowerUser = true
                        } label: {
                            Image(systemName: "ellipsis")
                                .font(.caption)
                                .foregroundStyle(Color.themeSubtext)
                                .frame(width: 36, height: 36)
                                .background(Circle().strokeBorder(Color.themeSubtext.opacity(0.3), lineWidth: 1))
                        }
                    }
                }
            }
        }
    }
    
    private var quickThemes: [ColorTheme] {
        isPowerUser ? Array(ColorTheme.allCases.prefix(8)) : [.gadfly, .defaultBlue, .emerald, .slate]
    }
    
    private func themeCircle(_ theme: ColorTheme) -> some View {
        let isSelected = themeColors.currentTheme == theme
        
        return Button {
            themeColors.currentTheme = theme
        } label: {
            Circle()
                .fill(theme.accent)
                .frame(width: 36, height: 36)
                .overlay(
                    Circle()
                        .strokeBorder(isSelected ? Color.white : Color.clear, lineWidth: 2)
                )
                .shadow(color: isSelected ? theme.accent.opacity(0.5) : .clear, radius: 4)
        }
    }
    
    private var quickTogglesRow: some View {
        HStack(spacing: 0) {
            quickToggle(icon: "speaker.wave.2.fill", label: "Sound", isOn: $soundsEnabled)
            Divider().frame(height: 32)
            quickToggle(icon: "iphone.radiowaves.left.and.right", label: "Vibrate", isOn: $hapticsEnabled)
            Divider().frame(height: 32)
            quickToggle(icon: "party.popper.fill", label: "Celebrate", isOn: $celebrationsEnabled)
        }
        .padding(.vertical, 10)
        .background(Color.themeSecondary)
        .cornerRadius(12)
    }
    
    private func quickToggle(icon: String, label: String, isOn: Binding<Bool>) -> some View {
        Button {
            isOn.wrappedValue.toggle()
        } label: {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.body)
                    .foregroundStyle(isOn.wrappedValue ? Color.themeAccent : Color.themeSubtext)
                Text(label)
                    .font(.caption2)
                    .foregroundStyle(isOn.wrappedValue ? Color.themeText : Color.themeSubtext)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
    }
    
    private var accessibilitySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Accessibility")
                .font(.caption.weight(.medium))
                .foregroundStyle(Color.themeSubtext)
            
            VStack(spacing: 0) {
                Toggle(isOn: $themeColors.isLightMode) {
                    HStack(spacing: 12) {
                        Image(systemName: themeColors.isLightMode ? "sun.max.fill" : "moon.fill")
                            .foregroundStyle(themeColors.isLightMode ? .orange : .indigo)
                            .frame(width: 24)
                        Text("Light Mode")
                            .font(.subheadline)
                            .foregroundStyle(Color.themeText)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                
                Divider().padding(.leading, 48)
                
                Toggle(isOn: $themeColors.highContrastMode) {
                    HStack(spacing: 12) {
                        Image(systemName: "circle.lefthalf.filled")
                            .foregroundStyle(Color.themeAccent)
                            .frame(width: 24)
                        Text("High Contrast")
                            .font(.subheadline)
                            .foregroundStyle(Color.themeText)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                
                Divider().padding(.leading, 48)
                
                HStack(spacing: 12) {
                    Image(systemName: "eye")
                        .foregroundStyle(Color.themeAccent)
                        .frame(width: 24)
                    Text("Color Vision")
                        .font(.subheadline)
                        .foregroundStyle(Color.themeText)
                    Spacer()
                    Picker("", selection: $themeColors.colorblindMode) {
                        ForEach(ColorblindMode.allCases) { mode in
                            Text(mode.displayName).tag(mode)
                        }
                    }
                    .pickerStyle(.menu)
                    .tint(Color.themeAccent)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                
                Divider().padding(.leading, 48)
                
                Toggle(isOn: $themeColors.reduceMotion) {
                    HStack(spacing: 12) {
                        Image(systemName: "figure.walk.motion")
                            .foregroundStyle(Color.themeAccent)
                            .frame(width: 24)
                        Text("Reduce Motion")
                            .font(.subheadline)
                            .foregroundStyle(Color.themeText)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                
                Divider().padding(.leading, 48)
                
                Toggle(isOn: $themeColors.muteSounds) {
                    HStack(spacing: 12) {
                        Image(systemName: themeColors.muteSounds ? "speaker.slash.fill" : "speaker.wave.2.fill")
                            .foregroundStyle(themeColors.muteSounds ? .gray : Color.themeAccent)
                            .frame(width: 24)
                        Text("Mute Sounds")
                            .font(.subheadline)
                            .foregroundStyle(Color.themeText)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                
                Divider().padding(.leading, 48)
                
                Toggle(isOn: $themeColors.reduceHaptics) {
                    HStack(spacing: 12) {
                        Image(systemName: "hand.tap.fill")
                            .foregroundStyle(Color.themeAccent)
                            .frame(width: 24)
                        Text("Reduce Haptics")
                            .font(.subheadline)
                            .foregroundStyle(Color.themeText)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
            }
            .background(Color.themeSecondary)
            .cornerRadius(12)
        }
    }
    
    private var powerUserToggle: some View {
        Button {
            withAnimation { isPowerUser.toggle() }
        } label: {
            HStack {
                Image(systemName: isPowerUser ? "star.fill" : "star")
                    .foregroundStyle(isPowerUser ? .yellow : Color.themeSubtext)
                Text(isPowerUser ? "Power User Mode" : "Show more options")
                    .font(.subheadline)
                    .foregroundStyle(Color.themeSubtext)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(Color.themeSubtext.opacity(0.5))
            }
            .padding()
            .background(Color.themeSecondary)
            .cornerRadius(12)
        }
    }
    
    private var advancedSection: some View {
        VStack(spacing: 0) {
            NavigationLink {
                PersonalityPickerView()
            } label: {
                settingsRow(icon: "theatermasks", title: "Personality", value: appState.selectedPersonality.displayName)
            }
            
            Divider().padding(.leading, 50)
            
            NavigationLink {
                CheckInQuickSetupView()
            } label: {
                settingsRow(icon: "clock", title: "Check-ins", value: "")
            }
            
            Divider().padding(.leading, 50)
            
            NavigationLink {
                LocationsManagerView()
            } label: {
                settingsRow(icon: "location", title: "Locations", value: "")
            }
            
            Divider().padding(.leading, 50)
            
            NavigationLink {
                APIKeysView()
            } label: {
                settingsRow(icon: "key", title: "API Keys", value: "")
            }
        }
        .background(Color.themeSecondary)
        .cornerRadius(16)
    }
    
    private func settingsRow(icon: String, title: String, value: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.body)
                .foregroundStyle(Color.themeAccent)
                .frame(width: 28)
            
            Text(title)
                .font(.body)
                .foregroundStyle(Color.themeText)
            
            Spacer()
            
            if !value.isEmpty {
                Text(value)
                    .font(.subheadline)
                    .foregroundStyle(Color.themeSubtext)
            }
            
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(Color.themeSubtext.opacity(0.5))
        }
        .padding()
    }
    
    private func applyHelpMode(_ mode: HelpMode) {
        switch mode {
        case .gentle:
            NaggingLevelService.shared.naggingLevel = .gentle
        case .balanced:
            NaggingLevelService.shared.naggingLevel = .moderate
        case .persistent:
            NaggingLevelService.shared.naggingLevel = .persistent
        }
    }
}

struct PersonalityPickerView: View {
    @EnvironmentObject var appState: AppState
    
    var body: some View {
        List {
            ForEach(BotPersonality.allCases) { personality in
                Button {
                    appState.selectedPersonality = personality
                } label: {
                    HStack {
                        Text(personality.emoji)
                            .font(.title2)
                        VStack(alignment: .leading) {
                            Text(personality.displayName)
                                .foregroundStyle(Color.themeText)
                            Text(personality.shortDescription)
                                .font(.caption)
                                .foregroundStyle(Color.themeSubtext)
                        }
                        Spacer()
                        if appState.selectedPersonality == personality {
                            Image(systemName: "checkmark")
                                .foregroundStyle(Color.themeAccent)
                        }
                    }
                }
            }
        }
        .navigationTitle("Personality")
    }
}

struct APIKeysView: View {
    @EnvironmentObject var appState: AppState
    
    var body: some View {
        Form {
            Section("Claude API") {
                SecureField("API Key", text: $appState.claudeKey)
            }
            Section("ElevenLabs") {
                SecureField("API Key", text: $appState.elevenLabsKey)
            }
        }
        .navigationTitle("API Keys")
    }
}

#Preview {
    SimpleSettingsView()
        .environmentObject(AppState())
}
