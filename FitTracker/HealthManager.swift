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
        // 1. Add 'HKWorkoutType' to the permissions list
        let typesToRead: Set = [
            HKObjectType.quantityType(forIdentifier: .heartRate)!,
            HKObjectType.quantityType(forIdentifier: .activeEnergyBurned)!,
            HKObjectType.workoutType() // <--- Crucial for reading Watch workouts
        ]
        
        healthStore.requestAuthorization(toShare: [], read: typesToRead) { success, error in
            if !success {
                print("Auth failed: \(String(describing: error))")
            }
        }
    }
    
    // 2. New Function: Import Cardio from Apple Watch
    func fetchAppleWatchWorkouts(completion: @escaping ([WorkoutSession]) -> Void) {
            let workoutType = HKObjectType.workoutType()
            let predicate: NSPredicate? = nil // Retrieve all, filter below
            
            let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)
            let limit = 20
            
            let query = HKSampleQuery(sampleType: workoutType, predicate: predicate, limit: limit, sortDescriptors: [sortDescriptor]) { _, samples, error in
                
                guard let hkWorkouts = samples as? [HKWorkout], error == nil else { return }
                
                var newSessions: [WorkoutSession] = []
                
                for hkWorkout in hkWorkouts {
                    var type: WorkoutType = .strength
                    
                    // FILTER: Only allow Running and Swimming
                    switch hkWorkout.workoutActivityType {
                    case .running: type = .run
                    case .swimming: type = .swim
                    default: continue // Skip Walking, Cycling, Yoga, etc.
                    }
                    
                    let distance = hkWorkout.totalDistance?.doubleValue(for: .meter())
                    
                    let session = WorkoutSession(
                        id: hkWorkout.uuid,
                        date: hkWorkout.startDate,
                        type: type,
                        distance: distance,
                        duration: hkWorkout.duration
                    )
                    newSessions.append(session)
                }
                
                DispatchQueue.main.async {
                    completion(newSessions)
                }
            }
            healthStore.execute(query)
        }
    
    func fetchAverageHeartRate(start: Date, end: Date, completion: @escaping (Double?) -> Void) {
            let heartRateType = HKQuantityType.quantityType(forIdentifier: .heartRate)!
            let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)
            
            // Create a statistics query to get the average
            let query = HKStatisticsQuery(quantityType: heartRateType, quantitySamplePredicate: predicate, options: .discreteAverage) { _, result, error in
                
                guard let result = result, let averageQuantity = result.averageQuantity() else {
                    print("No heart rate data found for this period")
                    DispatchQueue.main.async { completion(nil) }
                    return
                }
                
                let averageBPM = averageQuantity.doubleValue(for: HKUnit.count().unitDivided(by: .minute()))
                DispatchQueue.main.async {
                    completion(averageBPM)
                }
            }
            
            healthStore.execute(query)
        }
    
    // ... (Keep your existing startMonitoring/stopMonitoring functions here) ...
    func startMonitoring() {
        if workoutStartDate == nil { workoutStartDate = Date() }
        if timer == nil {
            timer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { _ in self.fetchLatestData() }
        }
    }
    
    func stopMonitoring() {
        timer?.invalidate()
        timer = nil
        workoutStartDate = nil
    }
    
    func fetchLatestData() {
        // ... (Keep existing HR/Calorie logic) ...
        // (If you need this code again, let me know, but don't delete it from your file!)
        let hrType = HKQuantityType.quantityType(forIdentifier: .heartRate)!
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)
        let hrQuery = HKSampleQuery(sampleType: hrType, predicate: nil, limit: 1, sortDescriptors: [sortDescriptor]) { _, samples, _ in
            if let sample = samples?.first as? HKQuantitySample {
                let bpm = sample.quantity.doubleValue(for: HKUnit.count().unitDivided(by: .minute()))
                if sample.startDate.timeIntervalSinceNow > -600 {
                    DispatchQueue.main.async { self.currentHeartRate = bpm }
                }
            }
        }
        healthStore.execute(hrQuery)
    }
}
