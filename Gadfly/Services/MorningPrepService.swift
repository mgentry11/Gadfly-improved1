import Foundation
import SwiftUI

@MainActor
class MorningPrepService: ObservableObject {
    static let shared = MorningPrepService()
    
    @Published var prepItems: [PrepItem] = []
    @Published var checkedItems: Set<String> = []
    @Published var itemLocations: [String: String] = [:]
    
    @Published var isEnabled: Bool {
        didSet { saveSettings() }
    }
    
    struct PrepItem: Identifiable, Codable {
        let id: String
        var icon: String
        var name: String
        var question: String
        var isActive: Bool
        var order: Int
        var isCustom: Bool
        
        init(id: String, icon: String, name: String, question: String, isActive: Bool = true, order: Int = 0, isCustom: Bool = false) {
            self.id = id
            self.icon = icon
            self.name = name
            self.question = question
            self.isActive = isActive
            self.order = order
            self.isCustom = isCustom
        }
    }
    
    static let defaultItems: [PrepItem] = [
        PrepItem(id: "wallet", icon: "creditcard.fill", name: "Wallet", question: "Do you have your wallet?", isActive: true, order: 0),
        PrepItem(id: "keys", icon: "key.fill", name: "Keys", question: "Do you have your keys?", isActive: true, order: 1),
        PrepItem(id: "phone", icon: "iphone", name: "Phone", question: "Do you have your phone?", isActive: true, order: 2),
        PrepItem(id: "bag", icon: "bag.fill", name: "Bag", question: "Do you have your bag packed?", isActive: true, order: 3),
        PrepItem(id: "headphones", icon: "airpodspro", name: "Headphones", question: "Do you have your headphones?", isActive: true, order: 4),
        PrepItem(id: "medication", icon: "pills.fill", name: "Medication", question: "Did you take your medication?", isActive: true, order: 5),
        PrepItem(id: "water", icon: "waterbottle.fill", name: "Water Bottle", question: "Do you have your water bottle?", isActive: true, order: 6),
        PrepItem(id: "laptop", icon: "laptopcomputer", name: "Laptop", question: "Do you have your laptop?", isActive: false, order: 7),
        PrepItem(id: "charger", icon: "battery.100.bolt", name: "Charger", question: "Do you have your charger?", isActive: false, order: 8),
        PrepItem(id: "glasses", icon: "eyeglasses", name: "Glasses", question: "Do you have your glasses?", isActive: false, order: 9),
        PrepItem(id: "badge", icon: "person.text.rectangle", name: "ID Badge", question: "Do you have your ID badge?", isActive: false, order: 10),
        PrepItem(id: "lunch", icon: "takeoutbag.and.cup.and.straw.fill", name: "Lunch", question: "Do you have your lunch?", isActive: false, order: 11),
        PrepItem(id: "umbrella", icon: "umbrella.fill", name: "Umbrella", question: "Do you need an umbrella today?", isActive: false, order: 12),
        PrepItem(id: "jacket", icon: "tshirt.fill", name: "Jacket", question: "Do you need a jacket?", isActive: false, order: 13),
    ]
    
    var activeItems: [PrepItem] {
        prepItems.filter { $0.isActive }.sorted { $0.order < $1.order }
    }
    
    var progress: Double {
        guard !activeItems.isEmpty else { return 0 }
        return Double(checkedItems.count) / Double(activeItems.count)
    }
    
    var isComplete: Bool {
        !activeItems.isEmpty && checkedItems.count == activeItems.count
    }
    
    private let userDefaults = UserDefaults.standard
    private let itemsKey = "morningPrep_items"
    private let locationsKey = "morningPrep_locations"
    private let enabledKey = "morningPrep_enabled"
    
    private init() {
        self.isEnabled = userDefaults.object(forKey: enabledKey) as? Bool ?? true
        loadItems()
        loadLocations()
        
        if prepItems.isEmpty {
            prepItems = Self.defaultItems
            saveItems()
        }
    }
    
    func markChecked(_ itemId: String) {
        checkedItems.insert(itemId)
    }
    
    func uncheck(_ itemId: String) {
        checkedItems.remove(itemId)
    }
    
    func setLocation(for itemId: String, location: String) {
        itemLocations[itemId] = location
        saveLocations()
    }
    
    func resetProgress() {
        checkedItems.removeAll()
    }
    
    func toggleItem(_ itemId: String) {
        if let index = prepItems.firstIndex(where: { $0.id == itemId }) {
            prepItems[index].isActive.toggle()
            saveItems()
        }
    }
    
    func addCustomItem(name: String, question: String, icon: String = "star.fill") {
        let id = "custom_\(UUID().uuidString)"
        let item = PrepItem(
            id: id,
            icon: icon,
            name: name,
            question: question,
            isActive: true,
            order: prepItems.count,
            isCustom: true
        )
        prepItems.append(item)
        saveItems()
    }
    
    func removeCustomItem(_ itemId: String) {
        prepItems.removeAll { $0.id == itemId }
        checkedItems.remove(itemId)
        itemLocations.removeValue(forKey: itemId)
        saveItems()
    }
    
    func moveItem(from source: IndexSet, to destination: Int) {
        prepItems.move(fromOffsets: source, toOffset: destination)
        reorderItems()
        saveItems()
    }
    
    private func reorderItems() {
        for (index, _) in prepItems.enumerated() {
            prepItems[index].order = index
        }
    }
    
    private func saveSettings() {
        userDefaults.set(isEnabled, forKey: enabledKey)
    }
    
    private func saveItems() {
        if let encoded = try? JSONEncoder().encode(prepItems) {
            userDefaults.set(encoded, forKey: itemsKey)
        }
    }
    
    private func loadItems() {
        if let data = userDefaults.data(forKey: itemsKey),
           let decoded = try? JSONDecoder().decode([PrepItem].self, from: data) {
            prepItems = decoded.sorted { $0.order < $1.order }
        }
    }
    
    private func saveLocations() {
        if let encoded = try? JSONEncoder().encode(itemLocations) {
            userDefaults.set(encoded, forKey: locationsKey)
        }
    }
    
    private func loadLocations() {
        if let data = userDefaults.data(forKey: locationsKey),
           let decoded = try? JSONDecoder().decode([String: String].self, from: data) {
            itemLocations = decoded
        }
    }
}
