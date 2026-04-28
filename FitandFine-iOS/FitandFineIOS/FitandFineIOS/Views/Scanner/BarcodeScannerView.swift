import SwiftUI
import AVFoundation
import Combine
import PhotosUI

// MARK: - Camera Preview

struct CameraPreviewView: UIViewRepresentable {
    let session: AVCaptureSession

    func makeUIView(context: Context) -> PreviewUIView {
        let view = PreviewUIView()
        view.session = session
        return view
    }

    func updateUIView(_ uiView: PreviewUIView, context: Context) {}
}

class PreviewUIView: UIView {
    override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
    var previewLayer: AVCaptureVideoPreviewLayer { layer as! AVCaptureVideoPreviewLayer }
    var session: AVCaptureSession? {
        get { previewLayer.session }
        set {
            previewLayer.session = newValue
            previewLayer.videoGravity = .resizeAspectFill
        }
    }
}

// MARK: - Camera Session ViewModel

@MainActor
class BarcodeScannerCameraViewModel: NSObject, ObservableObject, AVCaptureMetadataOutputObjectsDelegate {
    let session = AVCaptureSession()
    @Published var detectedBarcode: String? = nil
    @Published var isTorchOn: Bool = false
    var lastScannedCode: String? = nil

    override init() {
        super.init()
    }

    func startSession() {
        guard !session.isRunning else { return }
        Task.detached { [weak self] in
            guard let self else { return }
            await self.setupSession()
            self.session.startRunning()
        }
    }

    func stopSession() {
        Task.detached { [weak self] in
            self?.session.stopRunning()
        }
    }

    private func setupSession() {
        session.beginConfiguration()
        guard
            let device = AVCaptureDevice.default(for: .video),
            let input = try? AVCaptureDeviceInput(device: device),
            session.canAddInput(input)
        else {
            session.commitConfiguration()
            return
        }
        session.addInput(input)

        let output = AVCaptureMetadataOutput()
        if session.canAddOutput(output) {
            session.addOutput(output)
            output.setMetadataObjectsDelegate(self, queue: .main)
            output.metadataObjectTypes = [.ean13, .ean8, .upce, .code128, .qr]
        }
        session.commitConfiguration()
    }

    func toggleTorch() {
        guard let device = AVCaptureDevice.default(for: .video), device.hasTorch else { return }
        try? device.lockForConfiguration()
        isTorchOn.toggle()
        device.torchMode = isTorchOn ? .on : .off
        device.unlockForConfiguration()
    }

    nonisolated func metadataOutput(
        _ output: AVCaptureMetadataOutput,
        didOutput objects: [AVMetadataObject],
        from connection: AVCaptureConnection
    ) {
        guard
            let first = objects.first as? AVMetadataMachineReadableCodeObject,
            let value = first.stringValue
        else { return }

        Task { @MainActor [weak self] in
            guard let self else { return }
            guard value != self.lastScannedCode else { return }
            self.lastScannedCode = value
            self.detectedBarcode = value
        }
    }
}

// MARK: - BarcodeScannerView
// Signature: BarcodeScannerView(viewModel: ScannerViewModel(), onAddToLog: { mealType, foodId in ... })

struct BarcodeScannerView: View {
    @StateObject private var cameraVM = BarcodeScannerCameraViewModel()
    @ObservedObject var viewModel: ScannerViewModel
    /// Called with (mealType, foodItemId) after a food is successfully logged.
    var onAddToLog: ((String, String) -> Void)?

    // Label scan via photo picker (works in Simulator + real device)
    @State private var showLabelResult = false
    @State private var photoPickerItem: PhotosPickerItem? = nil
    @State private var showPhotoPicker = false

    var body: some View {
        ZStack {
            // Camera feed
            CameraPreviewView(session: cameraVM.session)
                .ignoresSafeArea()

            // Scanning overlay — viewfinder frame
            VStack {
                Spacer().frame(height: 120)
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.white, lineWidth: 2)
                    .frame(width: 260, height: 160)
                    .overlay(alignment: .bottom) {
                        Text("Align barcode within frame")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.8))
                            .padding(.bottom, -30)
                    }
                Spacer()
            }

            // Controls: torch + scan-label button
            VStack {
                HStack {
                    // 📷 Scan nutrition label button (photo picker)
                    PhotosPicker(selection: $photoPickerItem, matching: .images) {
                        HStack(spacing: 6) {
                            Image(systemName: "text.viewfinder")
                            Text("Scan Label")
                                .font(.caption.weight(.semibold))
                        }
                        .foregroundStyle(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 9)
                        .background(.black.opacity(0.55))
                        .clipShape(Capsule())
                    }
                    .padding()

                    Spacer()

                    Button {
                        cameraVM.toggleTorch()
                    } label: {
                        Image(systemName: cameraVM.isTorchOn ? "bolt.fill" : "bolt.slash.fill")
                            .font(.title2)
                            .foregroundStyle(.white)
                            .padding(12)
                            .background(.black.opacity(0.5))
                            .clipShape(Circle())
                    }
                    .padding()
                }
                Spacer()
            }

            // Food result card (slides up from bottom)
            if let food = viewModel.scannedFood {
                VStack {
                    Spacer()
                    FoodResultCard(food: food) { mealType, quantity in
                        viewModel.selectedMealType = mealType
                        viewModel.quantity = quantity
                        Task {
                            if let result = await viewModel.addToLog() {
                                viewModel.reset()
                                cameraVM.lastScannedCode = nil
                                onAddToLog?(result.0, result.1)
                            }
                        }
                    }
                    .padding()
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
                .animation(.spring(), value: viewModel.scannedFood != nil)
            }

            // Uploading spinner
            if viewModel.isUploading {
                ZStack {
                    Color.black.opacity(0.5).ignoresSafeArea()
                    VStack(spacing: 12) {
                        ProgressView().tint(.white).scaleEffect(1.5)
                        Text("Analysing label with AI…")
                            .font(.subheadline)
                            .foregroundStyle(.white)
                    }
                }
            }

            // Searching spinner
            if viewModel.isSearching {
                ProgressView()
                    .tint(.white)
                    .scaleEffect(1.5)
            }
        }
        .navigationTitle("Scan")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .onAppear { cameraVM.startSession() }
        .onDisappear { cameraVM.stopSession() }
        .onChange(of: cameraVM.detectedBarcode) { _, barcode in
            if let barcode, !viewModel.isSearching {
                Task { await viewModel.lookupBarcode(barcode) }
            }
        }
        // Handle selected photo for label scan
        .onChange(of: photoPickerItem) { _, item in
            guard let item else { return }
            Task {
                if let data = try? await item.loadTransferable(type: Data.self) {
                    await viewModel.scanNutritionLabel(imageData: data)
                    if viewModel.labelScanResult != nil {
                        showLabelResult = true
                    }
                }
                photoPickerItem = nil
            }
        }
        .sheet(isPresented: $showLabelResult) {
            LabelScanResultView(viewModel: viewModel) { mealType, foodItemId in
                showLabelResult = false
                onAddToLog?(mealType, foodItemId)
            }
        }
        .alert("Error", isPresented: Binding(
            get: { viewModel.errorMessage != nil },
            set: { if !$0 { viewModel.errorMessage = nil } }
        )) {
            Button("OK") {
                viewModel.errorMessage = nil
                cameraVM.detectedBarcode = nil
                cameraVM.lastScannedCode = nil
            }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
    }
}
