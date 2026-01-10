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
    @State private var position: MapCameraPosition = .userLocation(fallback: .automatic)
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
            .mapControls {
                MapUserLocationButton()
                MapCompass()
                MapScaleView()
            }
            .navigationTitle("Workout Map")
            // 4. The Popup Sheet
            .sheet(item: $selectedCluster) { cluster in
                GymDetailSheet(cluster: cluster)
                    .presentationDetents([.medium, .large]) // Allows half-height sheet
            }
        }
    }
}

// 5. The Detail View for the Sheet
struct GymDetailSheet: View {
    let cluster: GymCluster
    
    var body: some View {
        NavigationStack {
            List {
                ForEach(cluster.workouts.sorted(by: { $0.date > $1.date })) { session in
                    HStack {
                        VStack(alignment: .leading) {
                            Text(session.date.formatted(date: .abbreviated, time: .shortened))
                                .font(.headline)
                            Text("\(session.exercises.count) Exercises")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text("\(Int(session.totalVolume)) lbs")
                            .bold()
                            .foregroundStyle(.blue)
                    }
                }
            }
            .navigationTitle("\(cluster.workouts.count) Sessions Here")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}
