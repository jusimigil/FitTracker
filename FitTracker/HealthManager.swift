import Foundation
import HealthKit
import SwiftUI
import Combine

class HealthManager: ObservableObject {
    static let shared = HealthManager()
    let healthStore = HKHealthStore()
    
    @Published var currentHeartRate: Double = 0
    @Published var activeCalories: Double = 0
    
    var timer: Timer?
    var workoutStartDate: Date?
    
    init() {
        requestAuthorization()
    }
    
    func requestAuthorization() {
        let typesToRead: Set = [
            HKObjectType.quantityType(forIdentifier: .heartRate)!,
            HKObjectType.quantityType(forIdentifier: .activeEnergyBurned)!
        ]
        
        healthStore.requestAuthorization(toShare: [], read: typesToRead) { success, error in
            if !success {
                print("Auth failed: \(String(describing: error))")
            }
        }
    }
    
    func startMonitoring() {
            // FIX: Only set the start date if it hasn't been set yet.
            // This prevents the timer from resetting when you switch views.
            if workoutStartDate == nil {
                workoutStartDate = Date()
            }
            
            // Prevent multiple timers from stacking up
            if timer == nil {
                timer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { _ in
                    self.fetchLatestData()
                }
            }
        }
    
    func stopMonitoring() {
            timer?.invalidate()
            timer = nil
            workoutStartDate = nil // Reset so the next workout starts at 00:00
        }
    func fetchLatestData() {
        // 1. Fetch Heart Rate (Latest Sample)
        let hrType = HKQuantityType.quantityType(forIdentifier: .heartRate)!
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)
        let hrQuery = HKSampleQuery(sampleType: hrType, predicate: nil, limit: 1, sortDescriptors: [sortDescriptor]) { _, samples, _ in
            if let sample = samples?.first as? HKQuantitySample {
                let bpm = sample.quantity.doubleValue(for: HKUnit.count().unitDivided(by: .minute()))
                // Only show if recent (last 10 mins)
                if sample.startDate.timeIntervalSinceNow > -600 {
                    DispatchQueue.main.async { self.currentHeartRate = bpm }
                }
            }
        }
        healthStore.execute(hrQuery)
        
        // 2. Fetch Calories (Sum since workout started)
        guard let startDate = workoutStartDate else { return }
        let calType = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned)!
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: Date(), options: .strictStartDate)
        
        let calQuery = HKStatisticsQuery(quantityType: calType, quantitySamplePredicate: predicate, options: .cumulativeSum) { _, result, _ in
            guard let result = result, let sum = result.sumQuantity() else { return }
            let totalCals = sum.doubleValue(for: HKUnit.kilocalorie())
            DispatchQueue.main.async { self.activeCalories = totalCals }
        }
        healthStore.execute(calQuery)
    }
}
