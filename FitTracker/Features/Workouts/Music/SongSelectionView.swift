import SwiftUI

struct SongSelectionView: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var searcher = SongSearcher()
    @State private var searchText = ""
    
    // Callback to send data back to the main view
    var onSelect: (SongResult) -> Void
    
    var body: some View {
        NavigationStack {
            List {
                if searcher.isLoading {
                    HStack {
                        Spacer()
                        ProgressView("Searching Database...")
                        Spacer()
                    }
                }
                
                ForEach(searcher.results) { song in
                    Button(action: {
                        onSelect(song)
                        dismiss()
                    }) {
                        HStack(spacing: 15) {
                            // Load Image from URL
                            AsyncImage(url: URL(string: song.artworkUrl100)) { image in
                                image.resizable()
                            } placeholder: {
                                Color.gray.opacity(0.3)
                            }
                            .frame(width: 50, height: 50)
                            .cornerRadius(8)
                            
                            VStack(alignment: .leading) {
                                Text(song.trackName)
                                    .font(.headline)
                                    .foregroundStyle(.primary)
                                Text(song.artistName)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
            .searchable(text: $searchText, prompt: "Search Song or Artist")
            .onSubmit(of: .search) {
                searcher.search(query: searchText)
            }
            .onChange(of: searchText) { _, newValue in
                if newValue.isEmpty { searcher.results = [] }
            }
            .navigationTitle("Add Workout Anthem")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}
