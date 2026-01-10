import Foundation
import HealthKit
import Combine

class HealthManager: ObservableObject {
    static let shared = HealthManager()
    let healthStore = HKHealthStore()
    
    @Published var currentHeartRate: Double = 0
    @Published var activeCalories: Double = 0
    
    // Live Monitoring
    private var heartRateQuery: HKObserverQuery?
    private var calorieQuery: HKObserverQuery?
    private var refreshTimer: Timer?
    var sessionStartDate: Date?
    
    // Auto-Sync
    private var autoSyncTimer: Timer?

    // MARK: - Authorization
    func requestAuthorization() {
        let types: Set = [
            HKObjectType.quantityType(forIdentifier: .heartRate)!,
            HKObjectType.quantityType(forIdentifier: .activeEnergyBurned)!,
            HKObjectType.workoutType()
        ]
        healthStore.requestAuthorization(toShare: [], read: types) { _, _ in }
    }
    
    // MARK: - AUTO SYNC (Runs & Swims)
    func startAutoSync(dataManager: DataManager) {
        // Run immediately once
        syncWorkouts(into: dataManager)
        
        // Then run every 5 minutes (300 seconds)
        autoSyncTimer?.invalidate()
        autoSyncTimer = Timer.scheduledTimer(withTimeInterval: 300, repeats: true) { [weak self] _ in
            print("🔄 Auto-syncing runs and swims...")
            self?.syncWorkouts(into: dataManager)
        }
    }
    
    func stopAutoSync() {
        autoSyncTimer?.invalidate()
        autoSyncTimer = nil
    }

    // MARK: - START MONITORING
    func startMonitoring(startTime: Date = Date()) {
        self.sessionStartDate = startTime.addingTimeInterval(-300)
        fetchLatestHeartRate()
        fetchTotalCalories()
        startHeartRateObserver()
        startCalorieObserver()
        
        stopTimer()
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { [weak self] _ in
            self?.fetchTotalCalories()
            self?.fetchLatestHeartRate()
        }
    }

    func stopMonitoring() {
        if let hr = heartRateQuery { healthStore.stop(hr) }
        if let cal = calorieQuery { healthStore.stop(cal) }
        stopTimer()
    }
    
    private func stopTimer() {
        refreshTimer?.invalidate()
        refreshTimer = nil
    }
    
    // MARK: - HEART RATE & CALORIE LOGIC (Standard)
    private func startHeartRateObserver() {
        guard let type = HKQuantityType.quantityType(forIdentifier: .heartRate) else { return }
        let query = HKObserverQuery(sampleType: type, predicate: nil) { [weak self] _, _, _ in
            self?.fetchLatestHeartRate()
        }
        healthStore.execute(query)
        healthStore.enableBackgroundDelivery(for: type, frequency: .immediate) { _, _ in }
    }
    
    private func fetchLatestHeartRate() {
        guard let type = HKQuantityType.quantityType(forIdentifier: .heartRate) else { return }
        let sort = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)
        let twoHoursAgo = Date().addingTimeInterval(-7200)
        let predicate = HKQuery.predicateForSamples(withStart: twoHoursAgo, end: nil, options: .strictStartDate)
        
        let query = HKSampleQuery(sampleType: type, predicate: predicate, limit: 1, sortDescriptors: [sort]) { [weak self] _, results, _ in
            if let sample = results?.first as? HKQuantitySample {
                let val = sample.quantity.doubleValue(for: HKUnit.count().unitDivided(by: .minute()))
                DispatchQueue.main.async { self?.currentHeartRate = val }
            }
        }
        healthStore.execute(query)
    }
    
    private func startCalorieObserver() {
        guard let type = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned) else { return }
        let query = HKObserverQuery(sampleType: type, predicate: nil) { [weak self] _, _, _ in
            self?.fetchTotalCalories()
        }
        healthStore.execute(query)
        healthStore.enableBackgroundDelivery(for: type, frequency: .immediate) { _, _ in }
    }
    
    private func fetchTotalCalories() {
        guard let type = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned),
              let start = sessionStartDate else { return }
        
        let predicate = HKQuery.predicateForSamples(withStart: start, end: Date(), options: .strictStartDate)
        let query = HKStatisticsQuery(quantityType: type, quantitySamplePredicate: predicate, options: .cumulativeSum) { [weak self] _, result, _ in
            let val = result?.sumQuantity()?.doubleValue(for: .kilocalorie()) ?? 0
            DispatchQueue.main.async {
                if self?.activeCalories != val { self?.activeCalories = val }
            }
        }
        healthStore.execute(query)
    }
    
    // MARK: - HELPERS (Sync Logic)
    func fetchAverageHeartRate(start: Date, end: Date, completion: @escaping (Double?) -> Void) {
        let type = HKQuantityType.quantityType(forIdentifier: .heartRate)!
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)
        let query = HKStatisticsQuery(quantityType: type, quantitySamplePredicate: predicate, options: .discreteAverage) { _, result, _ in
            let avg = result?.averageQuantity()?.doubleValue(for: HKUnit.count().unitDivided(by: .minute()))
            DispatchQueue.main.async { completion(avg) }
        }
        healthStore.execute(query)
    }

    func syncWorkouts(into dataManager: DataManager) {
        let type = HKObjectType.workoutType()
        let sort = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)
        let query = HKSampleQuery(sampleType: type, predicate: nil, limit: 20, sortDescriptors: [sort]) { _, samples, _ in
            guard let hkWorkouts = samples as? [HKWorkout] else { return }
            
            // Filter for Runs and Swims
            let relevantWorkouts = hkWorkouts.filter { $0.workoutActivityType == .running || $0.workoutActivityType == .swimming }
            
            var newSessions: [WorkoutSession] = []
            
            for hkWorkout in relevantWorkouts {
                // Determine Type
                var type: WorkoutType = .run
                if hkWorkout.workoutActivityType == .swimming { type = .swim }
                
                // Duplicate Check
                let exists = dataManager.workouts.contains { existing in
                    return existing.id == hkWorkout.uuid || abs(existing.date.timeIntervalSince(hkWorkout.startDate)) < 1.0
                }
                
                if !exists {
                    var session = WorkoutSession(
                        id: hkWorkout.uuid,
                        date: hkWorkout.startDate,
                        type: type, // .run or .swim
                        distance: hkWorkout.totalDistance?.doubleValue(for: .meter()),
                        duration: hkWorkout.duration,
                        activeCalories: hkWorkout.totalEnergyBurned?.doubleValue(for: .kilocalorie())
                    )
                    session.isCompleted = true // Imported workouts are always done
                    newSessions.append(session)
                }
            }
            
            if !newSessions.isEmpty {
                DispatchQueue.main.async {
                    dataManager.workouts.append(contentsOf: newSessions)
                    dataManager.save()
                    print("✅ Auto-synced \(newSessions.count) new runs/swims.")
                }
            }
        }
        healthStore.execute(query)
    }
}
