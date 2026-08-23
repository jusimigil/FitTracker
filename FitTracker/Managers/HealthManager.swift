import Foundation
import HealthKit
import Combine

class HealthManager: ObservableObject {
    static let shared = HealthManager()
    let healthStore = HKHealthStore()
    
    @Published var currentHeartRate: Double = 0
    @Published var activeCalories: Double = 0
    @Published var currentSteps: Int = 0 // <--- NEW: Live Step Count
    @Published var lastNightSleepHours: Double = 0
    @Published var restingHeartRate: Double = 0
    
    // Live Monitoring
    private var heartRateQuery: HKObserverQuery?
    private var calorieQuery: HKObserverQuery?
    private var refreshTimer: Timer?
    var sessionStartDate: Date?
    private var sleepAuthorizationRequested = false
    
    // Auto-Sync
    private var autoSyncTimer: Timer?

    // MARK: - Authorization
    func requestAuthorization() {
        guard HKHealthStore.isHealthDataAvailable() else {
            print("❌ HealthKit is not available.")
            return
        }

        guard
            let heartRateType = HKQuantityType.quantityType(
                forIdentifier: .heartRate
            ),
            let restingHeartRateType = HKQuantityType.quantityType(
                forIdentifier: .restingHeartRate
            ),
            let caloriesType = HKQuantityType.quantityType(
                forIdentifier: .activeEnergyBurned
            ),
            let stepsType = HKQuantityType.quantityType(
                forIdentifier: .stepCount
            ),
            let sleepType = HKCategoryType.categoryType(
                forIdentifier: .sleepAnalysis
            )
        else {
            print("❌ Could not create HealthKit types.")
            return
        }

        let readTypes: Set<HKObjectType> = [
            heartRateType,
            restingHeartRateType,
            caloriesType,
            stepsType,
            sleepType,
            HKObjectType.workoutType()
        ]

        sleepAuthorizationRequested = true

        healthStore.requestAuthorization(
            toShare: [],
            read: readTypes
        ) { [weak self] success, error in
            if let error {
                print(
                    "❌ HealthKit authorization error: \(error.localizedDescription)"
                )
                return
            }

            print(
                success
                    ? "✅ HealthKit authorization request completed."
                    : "⚠️ HealthKit authorization request did not complete."
            )

            // Give HealthKit a moment to finish updating its authorization
            // state before performing the first sleep query.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self?.fetchLastNightSleep()
            }
        }
    }
    
    // MARK: - NEW: FETCH STEPS
    func fetchTodaySteps() {
        guard let type = HKQuantityType.quantityType(forIdentifier: .stepCount) else { return }
        
        let now = Date()
        let startOfDay = Calendar.current.startOfDay(for: now)
        let predicate = HKQuery.predicateForSamples(withStart: startOfDay, end: now, options: .strictStartDate)
        
        let query = HKStatisticsQuery(quantityType: type, quantitySamplePredicate: predicate, options: .cumulativeSum) { _, result, _ in
            let steps = result?.sumQuantity()?.doubleValue(for: HKUnit.count()) ?? 0
            DispatchQueue.main.async {
                self.currentSteps = Int(steps)
            }
        }
        healthStore.execute(query)
    }
    
    // MARK: - FETCH LAST NIGHT'S SLEEP

    func fetchLastNightSleep() {
        
        guard let sleepType = HKObjectType.categoryType(
            forIdentifier: .sleepAnalysis
        ) else {
            return
        }
        
        let calendar = Calendar.current
        let now = Date()
        
        // Search back far enough to cover a normal overnight sleep period.
        let startOfSearch = calendar.date(
            byAdding: .hour,
            value: -18,
            to: now
        ) ?? now.addingTimeInterval(-18 * 60 * 60)
        
        let predicate = HKQuery.predicateForSamples(
            withStart: startOfSearch,
            end: now,
            options: .strictStartDate
        )
        
        let sortDescriptor = NSSortDescriptor(
            key: HKSampleSortIdentifierStartDate,
            ascending: true
        )
        
        let query = HKSampleQuery(
            sampleType: sleepType,
            predicate: predicate,
            limit: HKObjectQueryNoLimit,
            sortDescriptors: [sortDescriptor]
        ) { [weak self] _, results, error in
            
            guard let self else {
                return
            }
            
            if let error {
                print("❌ Sleep query error: \(error)")
                return
            }
            
            guard let samples = results as? [HKCategorySample] else {
                DispatchQueue.main.async {
                    self.lastNightSleepHours = 0
                }
                return
            }
            
            let asleepValues: Set<Int> = [
                HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue,
                HKCategoryValueSleepAnalysis.asleepCore.rawValue,
                HKCategoryValueSleepAnalysis.asleepDeep.rawValue,
                HKCategoryValueSleepAnalysis.asleepREM.rawValue
            ]
            
            let sleepSamples = samples.filter {
                asleepValues.contains($0.value)
            }
            
            guard !sleepSamples.isEmpty else {
                DispatchQueue.main.async {
                    self.lastNightSleepHours = 0
                }
                print("😴 No sleep data found.")
                return
            }
            
            // Merge overlapping sleep samples so multiple Health sources
            // don't double-count the same sleep interval.
            var intervals: [(start: Date, end: Date)] = []
            
            for sample in sleepSamples {
                intervals.append(
                    (
                        start: sample.startDate,
                        end: sample.endDate
                    )
                )
            }
            
            intervals.sort {
                $0.start < $1.start
            }
            
            var mergedIntervals: [
                (start: Date, end: Date)
            ] = []
            
            for interval in intervals {
                
                guard let last = mergedIntervals.last else {
                    mergedIntervals.append(interval)
                    continue
                }
                
                if interval.start <= last.end {
                    
                    let mergedEnd = max(
                        last.end,
                        interval.end
                    )
                    
                    mergedIntervals[
                        mergedIntervals.count - 1
                    ] = (
                        start: last.start,
                        end: mergedEnd
                    )
                    
                } else {
                    mergedIntervals.append(interval)
                }
            }
            
            let totalSeconds = mergedIntervals.reduce(0.0) {
                $0 + $1.end.timeIntervalSince($1.start)
            }
            
            let hours = totalSeconds / 3600.0
            
            DispatchQueue.main.async {
                self.lastNightSleepHours = hours
                
                print(
                    "😴 Last night's sleep: " +
                    String(format: "%.2f", hours) +
                    " hours"
                )
            }
        }
        
        healthStore.execute(query)
    }
    
    // MARK: - FETCH RESTING HEART RATE

    func fetchRestingHeartRate() {
        
        guard let type = HKQuantityType.quantityType(
            forIdentifier: .restingHeartRate
        ) else {
            return
        }
        
        let now = Date()
        let startDate = Calendar.current.date(
            byAdding: .day,
            value: -2,
            to: now
        ) ?? now.addingTimeInterval(-172800)
        
        let predicate = HKQuery.predicateForSamples(
            withStart: startDate,
            end: now,
            options: .strictStartDate
        )
        
        let sortDescriptor = NSSortDescriptor(
            key: HKSampleSortIdentifierStartDate,
            ascending: false
        )
        
        let query = HKSampleQuery(
            sampleType: type,
            predicate: predicate,
            limit: 1,
            sortDescriptors: [sortDescriptor]
        ) { [weak self] _, results, error in
            
            guard let self else {
                return
            }
            
            if let error {
                print(
                    "❌ Resting heart rate query error: \(error.localizedDescription)"
                )
                return
            }
            
            guard let sample = results?.first as? HKQuantitySample else {
                DispatchQueue.main.async {
                    self.restingHeartRate = 0
                }
                
                print("❤️ No resting heart rate data found.")
                return
            }
            
            let value = sample.quantity.doubleValue(
                for: HKUnit.count().unitDivided(by: .minute())
            )
            
            DispatchQueue.main.async {
                self.restingHeartRate = value
                
                print(
                    "❤️ Resting heart rate: " +
                    String(format: "%.0f", value) +
                    " bpm"
                )
            }
        }
        
        healthStore.execute(query)
    }
    
    // MARK: - AUTO SYNC (Runs & Swims & Steps)
    func startAutoSync(dataManager: DataManager) {
        
        // Existing syncs
        syncWorkouts(into: dataManager)
        fetchTodaySteps()
        fetchRestingHeartRate()
        fetchLastNightSleep()
        
        // Request HealthKit access.
        // Sleep is fetched from the authorization completion above.
        requestAuthorization()
        
        autoSyncTimer?.invalidate()
        
        autoSyncTimer = Timer.scheduledTimer(
            withTimeInterval: 300,
            repeats: true
        ) { [weak self] _ in
            
            print("🔄 Auto-syncing data...")
            
            self?.syncWorkouts(into: dataManager)
            self?.fetchTodaySteps()
            self?.fetchLastNightSleep()
            self?.fetchRestingHeartRate()
        }
    }
            
    func stopAutoSync() {
        autoSyncTimer?.invalidate()
        autoSyncTimer = nil
    }

    // MARK: - START MONITORING WORKOUT
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
    
    // MARK: - HEART RATE & CALORIE LOGIC
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
            
            let relevantWorkouts = hkWorkouts.filter { $0.workoutActivityType == .running || $0.workoutActivityType == .swimming }
            var newSessions: [WorkoutSession] = []
            
            for hkWorkout in relevantWorkouts {
                var type: WorkoutType = .run
                if hkWorkout.workoutActivityType == .swimming { type = .swim }
                
                let exists = dataManager.workouts.contains { existing in
                    return existing.id == hkWorkout.uuid || abs(existing.date.timeIntervalSince(hkWorkout.startDate)) < 1.0
                }
                
                if !exists {
                    var session = WorkoutSession(
                        id: hkWorkout.uuid,
                        date: hkWorkout.startDate,
                        type: type,
                        distance: hkWorkout.totalDistance?.doubleValue(for: .meter()),
                        duration: hkWorkout.duration,
                        activeCalories: hkWorkout.totalEnergyBurned?.doubleValue(for: .kilocalorie())
                    )
                    session.isCompleted = true
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
