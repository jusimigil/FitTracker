import SwiftUI
import Combine

// 1. The Data Structure for API Results
struct ITunesResponse: Codable {
    let results: [SongResult]
}

struct SongResult: Codable, Identifiable {
    let trackId: Int
    let trackName: String
    let artistName: String
    let artworkUrl100: String // The album cover
    
    var id: Int { trackId }
}

// 2. The Search Manager
class SongSearcher: ObservableObject {
    @Published var results: [SongResult] = []
    @Published var isLoading = false
    
    private var cancellables = Set<AnyCancellable>()
    
    func search(query: String) {
        guard !query.isEmpty else { return }
        
        // Cleanup query for URL
        let cleanedQuery = query.replacingOccurrences(of: " ", with: "+")
        let urlString = "https://itunes.apple.com/search?term=\(cleanedQuery)&entity=song&limit=20"
        
        guard let url = URL(string: urlString) else { return }
        
        isLoading = true
        
        URLSession.shared.dataTaskPublisher(for: url)
            .map { $0.data }
            .decode(type: ITunesResponse.self, decoder: JSONDecoder())
            .map { $0.results }
            .replaceError(with: [])
            .receive(on: DispatchQueue.main)
            .sink { [weak self] songs in
                self?.isLoading = false
                self?.results = songs
            }
            .store(in: &cancellables)
    }
}
