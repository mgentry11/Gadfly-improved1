import SwiftUI

struct EditCheckInItemsView: View {
    let checkInType: CheckInType
    
    @ObservedObject private var morningService = MorningChecklistService.shared
    @ObservedObject private var dayStructure = DayStructureService.shared
    @ObservedObject private var themeColors = ThemeColors.shared
    @Environment(\.dismiss) private var dismiss
    
    @State private var newItemText = ""
    @FocusState private var isTextFieldFocused: Bool
    
    enum CheckInType: String, Identifiable {
        case morning
        case bedtime
        
        var id: String { rawValue }
        
        var title: String {
            switch self {
            case .morning: return "Morning Items"
            case .bedtime: return "Bedtime Items"
            }
        }
        
        var icon: String {
            switch self {
            case .morning: return "sunrise.fill"
            case .bedtime: return "moon.stars.fill"
            }
        }
        
        var color: Color {
            switch self {
            case .morning: return .orange
            case .bedtime: return .indigo
            }
        }
        
        var placeholder: String {
            switch self {
            case .morning: return "e.g., Check I have my keys"
            case .bedtime: return "e.g., Brush teeth"
            }
        }
        
        var suggestions: [(String, String)] {
            switch self {
            case .morning:
                return [
                    ("Phone", "iphone"),
                    ("Keys", "key.fill"),
                    ("Wallet", "creditcard.fill"),
                    ("Glasses", "eyeglasses"),
                    ("Headphones", "headphones"),
                    ("Lunch/snacks", "takeoutbag.and.cup.and.straw.fill"),
                    ("Water bottle", "waterbottle.fill"),
                    ("Work badge/ID", "person.text.rectangle"),
                    ("Charger/cables", "cable.connector"),
                    ("Bag packed", "bag.fill"),
                    ("Jacket/coat", "cloud.snow.fill"),
                    ("Umbrella", "umbrella.fill"),
                    ("Lock door", "lock.fill"),
                    ("Lights off", "lightbulb.slash"),
                    ("Stove off", "flame.fill"),
                    ("Windows closed", "window.horizontal.closed"),
                    ("Medication", "pills.fill"),
                    ("Pet fed", "pawprint.fill"),
                ]
            case .bedtime:
                return [
                    ("Brush teeth", "mouth.fill"),
                    ("Take meds", "pills.fill"),
                    ("Wash face", "drop.fill"),
                    ("Floss", "rays"),
                    ("Lock doors", "lock.fill"),
                    ("Stove off", "flame.fill"),
                    ("Set alarm", "alarm.fill"),
                    ("Phone charging", "battery.100.bolt"),
                    ("Keys in spot", "key.fill"),
                    ("Wallet in spot", "creditcard.fill"),
                    ("Clothes for tomorrow", "tshirt.fill"),
                    ("Bag packed", "bag.fill"),
                    ("Check weather", "cloud.sun.fill"),
                    ("Lights off", "lightbulb.slash"),
                ]
            }
        }
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                quickAddBar
                
                ScrollView {
                    VStack(spacing: 16) {
                        currentItemsList
                        suggestionsGrid
                    }
                    .padding()
                }
            }
            .background(Color.themeBackground)
            .navigationTitle(checkInType.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .fontWeight(.semibold)
                }
            }
        }
    }
    
    private var quickAddBar: some View {
        HStack(spacing: 12) {
            Image(systemName: "plus.circle.fill")
                .font(.title2)
                .foregroundStyle(checkInType.color)
            
            TextField(checkInType.placeholder, text: $newItemText)
                .focused($isTextFieldFocused)
                .submitLabel(.done)
                .onSubmit { addNewItem() }
            
            if !newItemText.isEmpty {
                Button("Add") {
                    addNewItem()
                }
                .fontWeight(.semibold)
                .foregroundStyle(checkInType.color)
            }
        }
        .padding()
        .background(Color.themeSecondary)
    }
    
    private var currentItemsList: some View {
        VStack(alignment: .leading, spacing: 8) {
            if itemCount == 0 {
                emptyState
            } else {
                Text("YOUR ITEMS")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(themeColors.subtext)
                    .padding(.leading, 4)
                
                VStack(spacing: 1) {
                    switch checkInType {
                    case .morning:
                        ForEach(morningService.selfChecks) { check in
                            morningItemRow(check)
                        }
                    case .bedtime:
                        ForEach(dayStructure.bedtimeItems) { item in
                            bedtimeItemRow(item)
                        }
                    }
                }
                .background(Color.themeSecondary)
                .cornerRadius(12)
            }
        }
    }
    
    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: checkInType.icon)
                .font(.system(size: 40))
                .foregroundStyle(checkInType.color.opacity(0.5))
            
            Text("No items yet")
                .font(.headline)
                .foregroundStyle(themeColors.text)
            
            Text("Type above or tap suggestions below")
                .font(.subheadline)
                .foregroundStyle(themeColors.subtext)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
        .background(Color.themeSecondary)
        .cornerRadius(12)
    }
    
    private func morningItemRow(_ check: MorningChecklistService.SelfCheck) -> some View {
        HStack(spacing: 12) {
            Button {
                morningService.toggleCheckActive(id: check.id)
            } label: {
                Image(systemName: check.isActive ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(check.isActive ? checkInType.color : themeColors.subtext)
            }
            
            Text(check.title)
                .foregroundStyle(check.isActive ? themeColors.text : themeColors.subtext)
                .strikethrough(!check.isActive)
            
            Spacer()
            
            Button {
                morningService.removeSelfCheck(id: check.id)
            } label: {
                Image(systemName: "trash")
                    .font(.caption)
                    .foregroundStyle(.red.opacity(0.7))
            }
        }
        .padding()
    }
    
    private func bedtimeItemRow(_ item: DayStructureService.CheckInItem) -> some View {
        HStack(spacing: 12) {
            Button {
                dayStructure.toggleBedtimeItem(id: item.id)
            } label: {
                Image(systemName: item.isEnabled ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(item.isEnabled ? checkInType.color : themeColors.subtext)
            }
            
            Image(systemName: item.icon)
                .font(.caption)
                .foregroundStyle(item.isEnabled ? themeColors.text : themeColors.subtext)
                .frame(width: 20)
            
            Text(item.title)
                .foregroundStyle(item.isEnabled ? themeColors.text : themeColors.subtext)
                .strikethrough(!item.isEnabled)
            
            Spacer()
            
            Button {
                dayStructure.removeBedtimeItem(id: item.id)
            } label: {
                Image(systemName: "trash")
                    .font(.caption)
                    .foregroundStyle(.red.opacity(0.7))
            }
        }
        .padding()
    }
    
    private var suggestionsGrid: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("QUICK ADD")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(themeColors.subtext)
                .padding(.leading, 4)
            
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 110), spacing: 8)], spacing: 8) {
                ForEach(filteredSuggestions, id: \.0) { suggestion in
                    Button {
                        addItem(title: suggestion.0, icon: suggestion.1)
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: suggestion.1)
                                .font(.caption)
                            Text(suggestion.0)
                                .font(.subheadline)
                        }
                        .foregroundStyle(themeColors.text)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .frame(maxWidth: .infinity)
                        .background(Color.themeSecondary)
                        .cornerRadius(10)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(checkInType.color.opacity(0.3), lineWidth: 1)
                        )
                    }
                }
            }
            
            Button {
                resetToDefaults()
            } label: {
                HStack {
                    Image(systemName: "arrow.counterclockwise")
                    Text("Reset to Defaults")
                }
                .font(.subheadline)
                .foregroundStyle(.red.opacity(0.8))
            }
            .padding(.top, 16)
        }
    }
    
    private var itemCount: Int {
        switch checkInType {
        case .morning: return morningService.selfChecks.count
        case .bedtime: return dayStructure.bedtimeItems.count
        }
    }
    
    private var filteredSuggestions: [(String, String)] {
        checkInType.suggestions.filter { suggestion in
            switch checkInType {
            case .morning:
                return !morningService.selfChecks.contains { $0.title.lowercased().contains(suggestion.0.lowercased()) }
            case .bedtime:
                return !dayStructure.bedtimeItems.contains { $0.title.lowercased().contains(suggestion.0.lowercased()) }
            }
        }
    }
    
    private func addNewItem() {
        let trimmed = newItemText.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        addItem(title: trimmed, icon: "checkmark.circle")
        newItemText = ""
    }
    
    private func addItem(title: String, icon: String) {
        withAnimation(.easeInOut(duration: 0.2)) {
            switch checkInType {
            case .morning:
                morningService.addSelfCheck(title)
            case .bedtime:
                dayStructure.addBedtimeItem(title: title, icon: icon)
            }
        }
    }
    
    private func resetToDefaults() {
        withAnimation {
            switch checkInType {
            case .morning:
                morningService.resetToDefaults()
            case .bedtime:
                dayStructure.bedtimeItems = DayStructureService.adhdBedtimeItems
            }
        }
    }
}

#Preview {
    EditCheckInItemsView(checkInType: .morning)
}
