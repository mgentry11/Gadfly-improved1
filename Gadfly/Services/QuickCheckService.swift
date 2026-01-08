import Foundation
import SwiftUI

@MainActor
class QuickCheckService: ObservableObject {
    static let shared = QuickCheckService()
    
    @Published var checkedItems: Set<String> = []
    @Published var customItems: [CheckItem] = []
    
    struct CheckItem: Identifiable, Codable {
        let id: String
        var icon: String
        var name: String
        var isActive: Bool
        var order: Int
        
        init(id: String, icon: String, name: String, isActive: Bool = true, order: Int = 0) {
            self.id = id
            self.icon = icon
            self.name = name
            self.isActive = isActive
            self.order = order
        }
    }
    
    static let defaultItems: [CheckItem] = [
        CheckItem(id: "wallet", icon: "creditcard.fill", name: "Wallet", order: 0),
        CheckItem(id: "keys", icon: "key.fill", name: "Keys", order: 1),
        CheckItem(id: "phone", icon: "iphone", name: "Phone", order: 2),
        CheckItem(id: "headphones", icon: "airpodspro", name: "Headphones", order: 3),
        CheckItem(id: "bag", icon: "bag.fill", name: "Bag", order: 4),
        CheckItem(id: "water", icon: "waterbottle.fill", name: "Water Bottle", order: 5),
        CheckItem(id: "laptop", icon: "laptopcomputer", name: "Laptop", isActive: false, order: 6),
        CheckItem(id: "charger", icon: "battery.100.bolt", name: "Charger", isActive: false, order: 7),
        CheckItem(id: "medication", icon: "pills.fill", name: "Medication", isActive: false, order: 8),
        CheckItem(id: "glasses", icon: "eyeglasses", name: "Glasses", isActive: false, order: 9),
        CheckItem(id: "badge", icon: "person.text.rectangle", name: "ID Badge", isActive: false, order: 10),
        CheckItem(id: "lunch", icon: "takeoutbag.and.cup.and.straw.fill", name: "Lunch", isActive: false, order: 11),
    ]
    
    var allItems: [CheckItem] {
        (Self.defaultItems + customItems).filter { $0.isActive }.sorted { $0.order < $1.order }
    }
    
    private let userDefaults = UserDefaults.standard
    private let customItemsKey = "quickCheck_customItems"
    private let checkedKey = "quickCheck_checked"
    
    private init() {
        loadCustomItems()
    }
    
    func isChecked(_ id: String) -> Bool {
        checkedItems.contains(id)
    }
    
    func toggle(_ id: String) {
        if checkedItems.contains(id) {
            checkedItems.remove(id)
        } else {
            checkedItems.insert(id)
        }
    }
    
    func check(_ id: String) {
        checkedItems.insert(id)
    }
    
    func reset() {
        checkedItems.removeAll()
    }
    
    func addCustomItem(name: String, icon: String = "star.fill") {
        let id = "custom_\(UUID().uuidString)"
        let item = CheckItem(id: id, icon: icon, name: name, order: allItems.count)
        customItems.append(item)
        saveCustomItems()
    }
    
    func removeCustomItem(_ id: String) {
        customItems.removeAll { $0.id == id }
        checkedItems.remove(id)
        saveCustomItems()
    }
    
    private func saveCustomItems() {
        if let encoded = try? JSONEncoder().encode(customItems) {
            userDefaults.set(encoded, forKey: customItemsKey)
        }
    }
    
    private func loadCustomItems() {
        if let data = userDefaults.data(forKey: customItemsKey),
           let decoded = try? JSONDecoder().decode([CheckItem].self, from: data) {
            customItems = decoded
        }
    }
}
