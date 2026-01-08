import Foundation
import CoreLocation
import UIKit

@MainActor
class SmartLocationService: NSObject, ObservableObject {
    static let shared = SmartLocationService()
    
    @Published var homeLocation: CLLocationCoordinate2D?
    @Published var isAtHome = false
    @Published var hasDetectedHome = false
    @Published var showLeavingHomeCheck = false
    
    private let locationManager = CLLocationManager()
    private var chargingLocations: [ChargingEvent] = []
    private let homeThresholdMeters: Double = 150
    private let minChargingEventsForHome = 3
    
    struct ChargingEvent: Codable {
        let latitude: Double
        let longitude: Double
        let timestamp: Date
        let wasOvernight: Bool
    }
    
    private let userDefaults = UserDefaults.standard
    private let homeKey = "smartLocation_home"
    private let chargingKey = "smartLocation_charging"
    
    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        loadSavedData()
        setupBatteryMonitoring()
    }
    
    func requestPermissions() {
        locationManager.requestWhenInUseAuthorization()
    }
    
    func requestAlwaysPermissions() {
        locationManager.requestAlwaysAuthorization()
    }
    
    private func setupBatteryMonitoring() {
        UIDevice.current.isBatteryMonitoringEnabled = true
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(batteryStateChanged),
            name: UIDevice.batteryStateDidChangeNotification,
            object: nil
        )
    }
    
    @objc private func batteryStateChanged() {
        let state = UIDevice.current.batteryState
        
        if state == .charging || state == .full {
            recordChargingLocation()
        }
    }
    
    private func recordChargingLocation() {
        guard locationManager.authorizationStatus == .authorizedAlways ||
              locationManager.authorizationStatus == .authorizedWhenInUse else { return }
        
        locationManager.requestLocation()
    }
    
    func didReceiveLocation(_ location: CLLocation) {
        let hour = Calendar.current.component(.hour, from: Date())
        let isOvernight = hour >= 22 || hour <= 6
        
        let event = ChargingEvent(
            latitude: location.coordinate.latitude,
            longitude: location.coordinate.longitude,
            timestamp: Date(),
            wasOvernight: isOvernight
        )
        
        chargingLocations.append(event)
        
        if chargingLocations.count > 50 {
            chargingLocations.removeFirst()
        }
        
        saveChargingEvents()
        analyzeHomeLocation()
    }
    
    private func analyzeHomeLocation() {
        let overnightEvents = chargingLocations.filter { $0.wasOvernight }
        
        guard overnightEvents.count >= minChargingEventsForHome else { return }
        
        let avgLat = overnightEvents.map { $0.latitude }.reduce(0, +) / Double(overnightEvents.count)
        let avgLon = overnightEvents.map { $0.longitude }.reduce(0, +) / Double(overnightEvents.count)
        
        let clusterCount = overnightEvents.filter { event in
            let distance = distanceBetween(
                lat1: event.latitude, lon1: event.longitude,
                lat2: avgLat, lon2: avgLon
            )
            return distance < homeThresholdMeters
        }.count
        
        let clusterRatio = Double(clusterCount) / Double(overnightEvents.count)
        
        if clusterRatio > 0.7 {
            homeLocation = CLLocationCoordinate2D(latitude: avgLat, longitude: avgLon)
            hasDetectedHome = true
            saveHomeLocation()
            startMonitoringHome()
        }
    }
    
    func setHomeManually(location: CLLocationCoordinate2D) {
        homeLocation = location
        hasDetectedHome = true
        saveHomeLocation()
        startMonitoringHome()
    }
    
    func setHomeToCurrentLocation() {
        guard locationManager.authorizationStatus == .authorizedAlways ||
              locationManager.authorizationStatus == .authorizedWhenInUse else {
            requestPermissions()
            return
        }
        
        locationManager.requestLocation()
    }
    
    private func startMonitoringHome() {
        guard let home = homeLocation,
              locationManager.authorizationStatus == .authorizedAlways else { return }
        
        let region = CLCircularRegion(
            center: home,
            radius: homeThresholdMeters,
            identifier: "home_region"
        )
        region.notifyOnExit = true
        region.notifyOnEntry = true
        
        locationManager.startMonitoring(for: region)
    }
    
    func checkIfLeavingHome() {
        guard let home = homeLocation else { return }
        
        locationManager.requestLocation()
    }
    
    private func distanceBetween(lat1: Double, lon1: Double, lat2: Double, lon2: Double) -> Double {
        let loc1 = CLLocation(latitude: lat1, longitude: lon1)
        let loc2 = CLLocation(latitude: lat2, longitude: lon2)
        return loc1.distance(from: loc2)
    }
    
    private func saveHomeLocation() {
        guard let home = homeLocation else { return }
        let dict: [String: Double] = ["lat": home.latitude, "lon": home.longitude]
        userDefaults.set(dict, forKey: homeKey)
    }
    
    private func saveChargingEvents() {
        if let encoded = try? JSONEncoder().encode(chargingLocations) {
            userDefaults.set(encoded, forKey: chargingKey)
        }
    }
    
    private func loadSavedData() {
        if let dict = userDefaults.dictionary(forKey: homeKey),
           let lat = dict["lat"] as? Double,
           let lon = dict["lon"] as? Double {
            homeLocation = CLLocationCoordinate2D(latitude: lat, longitude: lon)
            hasDetectedHome = true
            startMonitoringHome()
        }
        
        if let data = userDefaults.data(forKey: chargingKey),
           let decoded = try? JSONDecoder().decode([ChargingEvent].self, from: data) {
            chargingLocations = decoded
        }
    }
    
    func clearHomeLocation() {
        homeLocation = nil
        hasDetectedHome = false
        userDefaults.removeObject(forKey: homeKey)
        
        for region in locationManager.monitoredRegions {
            if region.identifier == "home_region" {
                locationManager.stopMonitoring(for: region)
            }
        }
    }
}

extension SmartLocationService: CLLocationManagerDelegate {
    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        Task { @MainActor in
            self.didReceiveLocation(location)
        }
    }
    
    nonisolated func locationManager(_ manager: CLLocationManager, didExitRegion region: CLRegion) {
        guard region.identifier == "home_region" else { return }
        Task { @MainActor in
            self.isAtHome = false
            self.showLeavingHomeCheck = true
        }
    }
    
    nonisolated func locationManager(_ manager: CLLocationManager, didEnterRegion region: CLRegion) {
        guard region.identifier == "home_region" else { return }
        Task { @MainActor in
            self.isAtHome = true
            self.showLeavingHomeCheck = false
        }
    }
    
    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("Location error: \(error)")
    }
    
    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor in
            if manager.authorizationStatus == .authorizedAlways {
                self.startMonitoringHome()
            }
        }
    }
}
