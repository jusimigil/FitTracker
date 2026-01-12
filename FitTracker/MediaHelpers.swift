import SwiftUI
import MediaPlayer
import AVFoundation
import Combine

// MARK: - 1. CAMERA PICKER (Standard)
struct ImagePicker: UIViewControllerRepresentable {
    @Binding var image: UIImage?
    @Environment(\.presentationMode) var mode
    
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        
        if UIImagePickerController.isSourceTypeAvailable(.camera) {
            picker.sourceType = .camera
        } else {
            picker.sourceType = .photoLibrary
        }
        
        picker.allowsEditing = false
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    
    func makeCoordinator() -> Coordinator { Coordinator(self) }
    
    class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        let parent: ImagePicker
        init(_ parent: ImagePicker) { self.parent = parent }
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let uiImage = info[.originalImage] as? UIImage { parent.image = uiImage }
            parent.mode.wrappedValue.dismiss()
        }
    }
}

// MARK: - 2. MUSIC MANAGER (The Fix)
class MusicManager: ObservableObject {
    static let shared = MusicManager()
    private let player = MPMusicPlayerController.systemMusicPlayer
    
    @Published var songTitle: String = "Not Playing"
    @Published var artistName: String = "Tap Play to Start"
    @Published var isPlaying: Bool = false
    @Published var albumArt: UIImage? = nil
    @Published var hasPermission: Bool = false
    
    init() {
        // FIX 1: Set Audio Session to "Ambient"
        // This stops your app from killing Spotify/Apple Music when it tries to interact with audio.
        do {
            try AVAudioSession.sharedInstance().setCategory(.ambient, options: .mixWithOthers)
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("Failed to set audio session: \(error)")
        }
        
        // FIX 2: Explicitly ask for permission
        requestPermission()
    }
    
    func requestPermission() {
        MPMediaLibrary.requestAuthorization { status in
            DispatchQueue.main.async {
                if status == .authorized {
                    self.hasPermission = true
                    self.setupNotifications()
                } else {
                    self.hasPermission = false
                    self.songTitle = "Permission Denied"
                    self.artistName = "Allow Access in Settings"
                }
            }
        }
    }
    
    func setupNotifications() {
        player.beginGeneratingPlaybackNotifications()
        
        NotificationCenter.default.addObserver(self, selector: #selector(updateInfo), name: .MPMusicPlayerControllerNowPlayingItemDidChange, object: player)
        NotificationCenter.default.addObserver(self, selector: #selector(updateInfo), name: .MPMusicPlayerControllerPlaybackStateDidChange, object: player)
        
        updateInfo()
    }
    
    deinit { player.endGeneratingPlaybackNotifications() }
    
    @objc func updateInfo() {
        DispatchQueue.main.async {
            self.isPlaying = (self.player.playbackState == .playing)
            
            if let item = self.player.nowPlayingItem {
                self.songTitle = item.title ?? "Unknown Title"
                self.artistName = item.artist ?? "Unknown Artist"
                self.albumArt = item.artwork?.image(at: CGSize(width: 60, height: 60))
            } else {
                // If using Spotify, 'nowPlayingItem' might be nil, but playbackState could still be playing.
                if self.isPlaying {
                    self.songTitle = "External Audio"
                    self.artistName = "Spotify / Other"
                } else {
                    self.songTitle = "Not Playing"
                    self.artistName = "No Audio Detected"
                }
                self.albumArt = nil
            }
        }
    }
    
    // Controls
    func togglePlayPause() {
        // Using commands without checking state can cause crashes if the queue is empty
        if player.playbackState == .playing {
            player.pause()
        } else {
            player.play()
        }
    }
    
    func skipForward() { player.skipToNextItem() }
    func skipBackward() { player.skipToPreviousItem() }
}

// MARK: - 3. WIDGET VIEW
struct MusicPlayerWidget: View {
    @ObservedObject var manager = MusicManager.shared
    
    var body: some View {
        HStack(spacing: 15) {
            // Art
            if let art = manager.albumArt {
                Image(uiImage: art)
                    .resizable().scaledToFill()
                    .frame(width: 50, height: 50).cornerRadius(8)
            } else {
                Image(systemName: "music.note.list")
                    .font(.title2).foregroundStyle(.pink)
                    .frame(width: 50, height: 50)
                    .background(Color.pink.opacity(0.1)).cornerRadius(8)
            }
            
            // Text
            VStack(alignment: .leading) {
                Text(manager.songTitle).font(.subheadline).bold().lineLimit(1)
                Text(manager.artistName).font(.caption).foregroundStyle(.secondary).lineLimit(1)
            }
            Spacer()
            
            // Controls
            HStack(spacing: 20) {
                Button(action: { manager.skipBackward() }) { Image(systemName: "backward.fill") }
                
                Button(action: { manager.togglePlayPause() }) {
                    Image(systemName: manager.isPlaying ? "pause.fill" : "play.fill")
                        .font(.title2)
                        .foregroundStyle(.blue)
                }
                
                Button(action: { manager.skipForward() }) { Image(systemName: "forward.fill") }
            }
            .foregroundStyle(.primary)
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
        .onAppear {
            // Re-check permission/status every time view appears
            if !manager.hasPermission {
                manager.requestPermission()
            }
            manager.updateInfo()
        }
    }
}
