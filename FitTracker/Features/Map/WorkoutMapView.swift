import SwiftUI
import MapKit
import CoreLocation

// 1. Helper Struct to Group Workouts
struct GymCluster: Identifiable, Hashable {
    let id = UUID()
    let coordinate: CLLocationCoordinate2D
    var workouts: [WorkoutSession]
    
    // Conformance for Map selection
    static func == (lhs: GymCluster, rhs: GymCluster) -> Bool {
        lhs.id == rhs.id
    }
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

struct WorkoutMapView: View {
    @EnvironmentObject var dataManager: DataManager
    
    // Map State
    @State private var position: MapCameraPosition =
        .automatic
    @State private var selectedCluster: GymCluster? // Tracks which pin you tapped
    
    // 2. Computed Property to Group Workouts by Location
    var gymClusters: [GymCluster] {
        var clusters: [GymCluster] = []
        
        for workout in dataManager.workouts {
            guard let lat = workout.latitude, let long = workout.longitude else { continue }
            
            // Check if we already have a cluster nearby (within ~20 meters)
            // 0.0002 degrees is roughly 20 meters
            if let index = clusters.firstIndex(where: {
                abs($0.coordinate.latitude - lat) < 0.0002 &&
                abs($0.coordinate.longitude - long) < 0.0002
            }) {
                clusters[index].workouts.append(workout)
            } else {
                // Create new cluster
                let newCluster = GymCluster(
                    coordinate: CLLocationCoordinate2D(latitude: lat, longitude: long),
                    workouts: [workout]
                )
                clusters.append(newCluster)
            }
        }
        return clusters
    }

    var body: some View {
        NavigationStack {
            // 3. Map with Selection Support
            Map(position: $position, selection: $selectedCluster) {
                
                ForEach(gymClusters) { cluster in
                    Marker(coordinate: cluster.coordinate) {
                        Text("\(cluster.workouts.count) Workouts")
                        Image(systemName: "dumbbell.fill")
                    }
                    .tint(.blue)
                    .tag(cluster) // This links the pin to the selection state
                }
                
                UserAnnotation() // Shows your blue dot
            }
            .onAppear {
                fitMapToWorkouts()
            }
            .mapControls {
                MapUserLocationButton()
                MapCompass()
                MapScaleView()
            }
            .navigationTitle("Workout Map")
            // 4. The Popup Sheet
            .sheet(item: $selectedCluster) { cluster in
                GymDetailSheet(
                    cluster: cluster
                )
                .environmentObject(dataManager)
                .presentationDetents([.medium, .large])
            }
        }
    }
    
    private func fitMapToWorkouts() {
        
        guard !gymClusters.isEmpty else {
            position = .userLocation(
                fallback: .automatic
            )
            return
        }
        
        let coordinates = gymClusters.map {
            $0.coordinate
        }
        
        let minLatitude = coordinates.map(\.latitude).min()!
        let maxLatitude = coordinates.map(\.latitude).max()!
        let minLongitude = coordinates.map(\.longitude).min()!
        let maxLongitude = coordinates.map(\.longitude).max()!
        
        let center = CLLocationCoordinate2D(
            latitude: (minLatitude + maxLatitude) / 2,
            longitude: (minLongitude + maxLongitude) / 2
        )
        
        let latitudeSpan = max(
            maxLatitude - minLatitude,
            0.01
        ) * 1.4
        
        let longitudeSpan = max(
            maxLongitude - minLongitude,
            0.01
        ) * 1.4
        
        position = .region(
            MKCoordinateRegion(
                center: center,
                span: MKCoordinateSpan(
                    latitudeDelta: latitudeSpan,
                    longitudeDelta: longitudeSpan
                )
            )
        )
    }
}

// 5. The Detail View for the Sheet
struct GymDetailSheet: View {
    
    let cluster: GymCluster
    
    @EnvironmentObject var dataManager: DataManager
    
    var body: some View {
        NavigationStack {
            List {
                ForEach(
                    cluster.workouts.sorted(by: { $0.date > $1.date })
                ) { session in
                    
                    VStack(alignment: .leading, spacing: 10) {
                        
                        HStack {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(workoutTitle(for: session))
                                    .font(.headline)
                                
                                Text(
                                    session.date.formatted(
                                        date: .abbreviated,
                                        time: .shortened
                                    )
                                )
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            }
                            
                            Spacer()
                            
                            if hasPRs(for: session) {
                                Image(systemName: "trophy.fill")
                                    .foregroundStyle(.orange)
                            }
                        }
                        
                        HStack(spacing: 16) {
                            Label(
                                "\(session.exercises.count)",
                                systemImage: "dumbbell.fill"
                            )
                            
                            Label(
                                "\(setCount(for: session))",
                                systemImage: "square.stack.3d.up.fill"
                            )
                            
                            Label(
                                dataManager.formatVolume(
                                    session.totalVolume
                                ),
                                systemImage: "chart.bar.fill"
                            )
                        }
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        
                        if let duration = session.duration {
                            Label(
                                durationText(duration),
                                systemImage: "clock.fill"
                            )
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        }
                        
                        if hasPRs(for: session) {
                            let count = prCount(for: session)
                            
                            Text(
                                count == 1
                                ? "🏆 1 Personal Record"
                                : "🏆 \(count) Personal Records"
                            )
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundStyle(.orange)
                        }
                    }
                    .padding(.vertical, 6)
                }
            }
            .navigationTitle(
                "\(cluster.workouts.count) Sessions Here"
            )
            .navigationBarTitleDisplayMode(.inline)
        }
    }
    
    private func workoutTitle(
        for session: WorkoutSession
    ) -> String {
        
        if let title = session.workoutTitle,
           !title.isEmpty {
            return title
        }
        
        if !session.notes.isEmpty,
           session.notes.count < 30 {
            return session.notes
        }
        
        return session.type.rawValue.capitalized
    }
    
    private func setCount(
        for session: WorkoutSession
    ) -> Int {
        session.exercises.reduce(0) {
            $0 + $1.sets.count
        }
    }
    
    private func hasPRs(
        for session: WorkoutSession
    ) -> Bool {
        dataManager.personalRecords.contains {
            $0.workoutID == session.id
        }
    }
    
    private func prCount(
        for session: WorkoutSession
    ) -> Int {
        dataManager.personalRecords.filter {
            $0.workoutID == session.id
        }.count
    }
    
    private func durationText(
        _ duration: TimeInterval
    ) -> String {
        let totalSeconds = Int(duration)
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        }
        
        return "\(minutes)m"
    }
}
