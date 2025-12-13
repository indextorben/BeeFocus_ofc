import Foundation
import SwiftUI
import PhotosUI
import AVFoundation

struct ImagesView: View {
    @Binding var images: [Data]
    @State private var selectedIndex: Int? = nil
    @Environment(\.dismiss) var dismiss
    
    @State private var showImageSourceDialog = false
    @State private var showCamera = false
    @State private var showPhotoPicker = false
    @State private var selectedPhoto: PhotosPickerItem?
    
    @State private var selectedItems: [PhotosPickerItem] = []
    @State private var selectedImages: [IdentifiableUIImage] = []
    @State private var selectedImageForPreview: IdentifiableUIImage?
    @State private var imageToDelete: IdentifiableUIImage?
    
    @ObservedObject private var localizer = LocalizationManager.shared
            let languages = ["Deutsch", "Englisch"]
    
    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 100), spacing: 12)], spacing: 12) {
                    ForEach(Array(images.enumerated()), id: \.offset) { index, imageData in
                        gridImageItem(imageData: imageData, index: index)
                    }
                    
                }
                .padding()
            }
            .navigationTitle("Bilder")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Fertig") {
                        dismiss()
                    }
                    .font(.headline)
                    .foregroundColor(.blue)
                }
            }
            .fullScreenCover(isPresented: Binding(
                get: { selectedIndex != nil },
                set: { if !$0 { selectedIndex = nil } }
            )) {
                if let index = selectedIndex {
                    FullscreenImageViewer(images: $images, selectedIndex: index)
                }
            }
            .photosPicker(isPresented: $showPhotoPicker,
                          selection: $selectedPhoto,
                          matching: .images)
            .fullScreenCover(isPresented: $showCamera) {
                if AVCaptureDevice.authorizationStatus(for: .video) == .authorized {
                } else {
                    CameraAccessView()
                }
            }
            .onChange(of: selectedPhoto) {
                Task {
                    if let data = try? await selectedPhoto?.loadTransferable(type: Data.self) {
                        DispatchQueue.main.async {
                            withAnimation {
                                images.append(data)
                            }
                        }
                    }
                    selectedPhoto = nil
                }
            }
        }
    }
    
    // MARK: - Subviews
    private func gridImageItem(imageData: Data, index: Int) -> some View {
        ZStack(alignment: .topTrailing) {
            if let uiImage = UIImage(data: imageData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 100, height: 100)
                    .clipped()
                    .cornerRadius(12)
                    .contentShape(Rectangle())
                    .onTapGesture { selectedIndex = index }
            } else {
                placeholderView
            }
        }
    }
    
    private var placeholderView: some View {
        RoundedRectangle(cornerRadius: 12)
            .fill(Color.gray.opacity(0.3))
            .frame(width: 100, height: 100)
            .overlay(
                Image(systemName: "photo")
                    .foregroundColor(.white)
            )
    }
    
    // MARK: - Helper Functions
    private func checkCameraPermission() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            showCamera = true
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                DispatchQueue.main.async {
                    if granted {
                        showCamera = true
                    }
                }
            }
        default:
            showCamera = true
        }
    }
    
    private func handleImagePicked(_ image: UIImage) {
        if let data = image.jpegData(compressionQuality: 0.8) {
            withAnimation {
                images.append(data)
            }
        }
    }
}

// MARK: - Fullscreen Image Viewer
struct FullscreenImageViewer: View {
    @Binding var images: [Data]
    var selectedIndex: Int
    @Environment(\.dismiss) var dismiss
    
    @State private var currentIndex: Int
    @State private var isZoomed = false
    
    init(images: Binding<[Data]>, selectedIndex: Int) {
        self._images = images
        self.selectedIndex = selectedIndex
        self._currentIndex = State(initialValue: selectedIndex)
    }
    
    var body: some View {
        ZStack(alignment: .topTrailing) {
            TabView(selection: $currentIndex) {
                ForEach(images.indices, id: \.self) { index in
                    if let uiImage = UIImage(data: images[index]) {
                        ZoomableImageView(image: Image(uiImage: uiImage), isZoomed: $isZoomed)
                            .tag(index)
                    }
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .always))
            .background(Color.black.ignoresSafeArea())
            .gesture(isZoomed ? nil : dragGesture)
            
            controlsOverlay
        }
    }
    
    // MARK: - Gestures
    private var dragGesture: some Gesture {
        DragGesture()
            .onEnded { value in
                if value.translation.width < -100 && currentIndex < images.count - 1 {
                    currentIndex += 1
                } else if value.translation.width > 100 && currentIndex > 0 {
                    currentIndex -= 1
                }
                
                if value.translation.height > 100 {
                    dismiss()
                }
            }
    }
    
    // MARK: - Controls
    private var controlsOverlay: some View {
        HStack(spacing: 16) {
            closeButton
        }
        .padding(.top, 40)
        .padding(.horizontal)
    }
    
    private var closeButton: some View {
        Button(action: { dismiss() }) {
            Image(systemName: "xmark")
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(.white)
                .padding(15)
                .background(Color.black.opacity(0.3))
                .clipShape(Circle())
        }
    }
}

// MARK: - Zoomable Image View
struct ZoomableImageView: View {
    let image: Image
    @Binding var isZoomed: Bool
    
    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero
    
    var body: some View {
        image
            .resizable()
            .scaledToFit()
            .scaleEffect(scale)
            .offset(offset)
            .gesture(doubleTapGesture)
            .gesture(dragGesture)
            .gesture(magnificationGesture)
            .onChange(of: scale) {
                isZoomed = scale > 1.0
            }
    }
    
    private var doubleTapGesture: some Gesture {
        TapGesture(count: 2).onEnded {
            if scale > 1.0 {
                resetZoom()
            } else {
                zoomToPoint()
            }
        }
    }
    
    private var dragGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                if scale > 1.0 {
                    offset = CGSize(
                        width: lastOffset.width + value.translation.width,
                        height: lastOffset.height + value.translation.height
                    )
                }
            }
            .onEnded { _ in
                lastOffset = offset
            }
    }
    
    private var magnificationGesture: some Gesture {
        MagnificationGesture()
            .onChanged { value in
                scale = lastScale * value
            }
            .onEnded { _ in
                withAnimation {
                    if scale < 1.0 {
                        resetZoom()
                    } else {
                        lastScale = scale
                    }
                }
            }
    }
    
    private func resetZoom() {
        withAnimation(.spring()) {
            scale = 1.0
            offset = .zero
            lastScale = 1.0
            lastOffset = .zero
            isZoomed = false
        }
    }
    
    private func zoomToPoint() {
        withAnimation(.interactiveSpring()) {
            scale = 3.0
            lastScale = 3.0
            isZoomed = true
        }
    }
}

// MARK: - Kamera-Zugriffs-Hinweis
struct CameraAccessView: View {
    var body: some View {
        VStack {
            Text("Kamera-Zugriff benötigt")
                .font(.headline)
                .padding()
            
            Text("Bitte erlaube den Kamerazugriff in den Einstellungen")
                .multilineTextAlignment(.center)
                .padding()
            
            Button("Zu Einstellungen") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            .buttonStyle(.borderedProminent)
            .padding()
        }
    }
}
