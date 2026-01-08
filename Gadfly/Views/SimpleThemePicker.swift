import SwiftUI

struct SimpleThemePicker: View {
    @ObservedObject private var themeColors = ThemeColors.shared
    @AppStorage("is_power_user") private var isPowerUser = false
    @State private var showAllThemes = false
    
    static let simpleThemes: [ColorTheme] = [.gadfly, .defaultBlue, .emerald, .slate]
    
    var displayedThemes: [ColorTheme] {
        if isPowerUser || showAllThemes {
            return Array(ColorTheme.allCases)
        }
        return Self.simpleThemes
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Theme")
                    .font(.headline)
                    .foregroundStyle(Color.themeText)
                
                Spacer()
                
                if !isPowerUser && !showAllThemes {
                    Button {
                        withAnimation { showAllThemes = true }
                    } label: {
                        Text("More")
                            .font(.caption)
                            .foregroundStyle(Color.themeAccent)
                    }
                }
            }
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                ForEach(displayedThemes) { theme in
                    themeButton(theme)
                }
            }
        }
        .padding()
        .background(Color.themeSecondary)
        .cornerRadius(16)
    }
    
    private func themeButton(_ theme: ColorTheme) -> some View {
        let isSelected = themeColors.currentTheme == theme
        
        return Button {
            themeColors.currentTheme = theme
        } label: {
            VStack(spacing: 8) {
                Circle()
                    .fill(theme.accent)
                    .frame(width: 44, height: 44)
                    .overlay(
                        Circle()
                            .strokeBorder(isSelected ? Color.white : Color.clear, lineWidth: 3)
                    )
                    .shadow(color: isSelected ? theme.accent.opacity(0.5) : .clear, radius: 8)
                
                Text(theme.displayName)
                    .font(.caption2)
                    .foregroundStyle(isSelected ? Color.themeText : Color.themeSubtext)
                    .lineLimit(1)
            }
        }
        .buttonStyle(.plain)
    }
}

extension ColorTheme {
    var displayName: String {
        switch self {
        case .gadfly: return "Amber"
        case .defaultBlue: return "Blue"
        case .emerald: return "Green"
        case .slate: return "Pink"
        default: return self.rawValue
        }
    }
}

struct QuickThemeBar: View {
    @ObservedObject private var themeColors = ThemeColors.shared
    
    private let quickThemes: [ColorTheme] = [.gadfly, .defaultBlue, .emerald, .slate]
    
    var body: some View {
        HStack(spacing: 16) {
            ForEach(quickThemes) { theme in
                Button {
                    themeColors.currentTheme = theme
                } label: {
                    Circle()
                        .fill(theme.accent)
                        .frame(width: 32, height: 32)
                        .overlay(
                            Circle()
                                .strokeBorder(
                                    themeColors.currentTheme == theme ? Color.white : Color.clear,
                                    lineWidth: 2
                                )
                        )
                }
            }
        }
    }
}

#Preview {
    SimpleThemePicker()
}
