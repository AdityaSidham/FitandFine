import SwiftUI
import AVFoundation
import Combine

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

// MARK: - Scanner Mode

enum ScannerMode { case barcode, label }

// MARK: - Camera Session ViewModel

@MainActor
class BarcodeScannerCameraViewModel: NSObject, ObservableObject,
    AVCaptureMetadataOutputObjectsDelegate, AVCapturePhotoCaptureDelegate {

    let session = AVCaptureSession()
    private let photoOutput = AVCapturePhotoOutput()

    @Published var detectedBarcode: String? = nil
    @Published var capturedImageData: Data? = nil
    @Published var isTorchOn: Bool = false
    @Published var isCapturing: Bool = false
    var lastScannedCode: String? = nil

    override init() { super.init() }

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

    private func setupSession() async {
        session.beginConfiguration()
        session.sessionPreset = .photo

        guard
            let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
            let input = try? AVCaptureDeviceInput(device: device),
            session.canAddInput(input)
        else {
            session.commitConfiguration()
            return
        }
        session.addInput(input)

        // Barcode metadata output
        let metaOutput = AVCaptureMetadataOutput()
        if session.canAddOutput(metaOutput) {
            session.addOutput(metaOutput)
            metaOutput.setMetadataObjectsDelegate(self, queue: .main)
            metaOutput.metadataObjectTypes = [.ean13, .ean8, .upce, .code128, .qr]
        }

        // Photo capture output (for label scanning)
        if session.canAddOutput(photoOutput) {
            session.addOutput(photoOutput)
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

    // MARK: - Capture photo for label scanning
    func capturePhoto() {
        guard !isCapturing else { return }
        isCapturing = true
        let settings = AVCapturePhotoSettings()
        settings.flashMode = isTorchOn ? .on : .off
        photoOutput.capturePhoto(with: settings, delegate: self)
    }

    // MARK: - AVCapturePhotoCaptureDelegate
    nonisolated func photoOutput(
        _ output: AVCapturePhotoOutput,
        didFinishProcessingPhoto photo: AVCapturePhoto,
        error: Error?
    ) {
        guard let data = photo.fileDataRepresentation() else { return }
        Task { @MainActor [weak self] in
            self?.capturedImageData = data
            self?.isCapturing = false
        }
    }

    // MARK: - AVCaptureMetadataOutputObjectsDelegate
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
            guard let self, value != self.lastScannedCode else { return }
            self.lastScannedCode = value
            self.detectedBarcode = value
            // Haptic feedback on successful scan
            let gen = UINotificationFeedbackGenerator()
            gen.notificationOccurred(.success)
        }
    }
}

// MARK: - BarcodeScannerView

struct BarcodeScannerView: View {
    @StateObject private var cameraVM = BarcodeScannerCameraViewModel()
    @ObservedObject var viewModel: ScannerViewModel
    var onAddToLog: ((String, String) -> Void)?

    @State private var mode: ScannerMode = .barcode
    @State private var showLabelResult = false
    @State private var shutterPressed = false

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            // Camera feed
            CameraPreviewView(session: cameraVM.session)
                .ignoresSafeArea()

            // Overlay
            VStack(spacing: 0) {
                // Top bar — mode toggle
                modeToggle
                    .padding(.top, 12)

                Spacer()

                // Viewfinder frame
                viewfinderFrame

                Spacer()

                // Bottom controls
                bottomBar
                    .padding(.bottom, 32)
            }

            // Food result card
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

            // AI analysis spinner
            if viewModel.isUploading {
                ZStack {
                    Color.black.opacity(0.6).ignoresSafeArea()
                    VStack(spacing: 16) {
                        ProgressView().tint(.white).scaleEffect(1.6)
                        Text("Analysing label with AI…")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.white)
                    }
                    .padding(28)
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                }
            }

            // Barcode lookup spinner
            if viewModel.isSearching {
                ProgressView().tint(.white).scaleEffect(1.5)
            }
        }
        .navigationTitle(mode == .barcode ? "Scan Barcode" : "Scan Label")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .onAppear { cameraVM.startSession() }
        .onDisappear { cameraVM.stopSession() }
        // Barcode auto-detected
        .onChange(of: cameraVM.detectedBarcode) { _, barcode in
            if let barcode, !viewModel.isSearching, mode == .barcode {
                Task { await viewModel.lookupBarcode(barcode) }
            }
        }
        // Photo captured for label scan
        .onChange(of: cameraVM.capturedImageData) { _, data in
            guard let data else { return }
            Task {
                await viewModel.scanNutritionLabel(imageData: data)
                if viewModel.labelScanResult != nil {
                    showLabelResult = true
                }
                cameraVM.capturedImageData = nil
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

    // MARK: - Mode Toggle

    private var modeToggle: some View {
        HStack(spacing: 0) {
            modeTab(title: "Barcode", icon: "barcode.viewfinder", tab: .barcode)
            modeTab(title: "Label",   icon: "text.viewfinder",    tab: .label)
        }
        .background(.black.opacity(0.45))
        .clipShape(Capsule())
        .padding(.horizontal, 60)
    }

    private func modeTab(title: String, icon: String, tab: ScannerMode) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) { mode = tab }
            cameraVM.lastScannedCode = nil
            viewModel.reset()
        } label: {
            HStack(spacing: 6) {
                Image(systemName: icon).font(.caption.weight(.semibold))
                Text(title).font(.subheadline.weight(.semibold))
            }
            .foregroundStyle(mode == tab ? .black : .white)
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
            .background(mode == tab ? Color.white : Color.clear)
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Viewfinder Frame

    private var viewfinderFrame: some View {
        ZStack {
            // Dimming outside frame
            Rectangle()
                .fill(.black.opacity(0.45))
                .mask(
                    Rectangle()
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .frame(
                                    width: mode == .barcode ? 280 : 300,
                                    height: mode == .barcode ? 140 : 200
                                )
                                .blendMode(.destinationOut)
                        )
                        .compositingGroup()
                )
                .ignoresSafeArea()

            // Frame corners
            RoundedRectangle(cornerRadius: 16)
                .stroke(.white, lineWidth: 2.5)
                .frame(
                    width: mode == .barcode ? 280 : 300,
                    height: mode == .barcode ? 140 : 200
                )

            // Hint text
            VStack {
                Spacer()
                    .frame(height: mode == .barcode ? 80 : 110)
                Text(mode == .barcode
                     ? "Point at a barcode — it scans automatically"
                     : "Frame the nutrition label, then tap the button below")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.85))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
                    .padding(.top, mode == .barcode ? 160 : 230)
            }
        }
    }

    // MARK: - Bottom Bar

    private var bottomBar: some View {
        HStack(alignment: .center) {
            // Torch button
            Button { cameraVM.toggleTorch() } label: {
                Image(systemName: cameraVM.isTorchOn ? "bolt.fill" : "bolt.slash.fill")
                    .font(.title2)
                    .foregroundStyle(cameraVM.isTorchOn ? .yellow : .white)
                    .frame(width: 52, height: 52)
                    .background(.black.opacity(0.5))
                    .clipShape(Circle())
            }

            Spacer()

            // Shutter button (label mode only)
            if mode == .label {
                Button {
                    shutterPressed = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { shutterPressed = false }
                    cameraVM.capturePhoto()
                } label: {
                    ZStack {
                        Circle()
                            .fill(.white)
                            .frame(width: 72, height: 72)
                        Circle()
                            .stroke(.white.opacity(0.4), lineWidth: 4)
                            .frame(width: 84, height: 84)
                        if cameraVM.isCapturing {
                            ProgressView().tint(.black).scaleEffect(1.2)
                        }
                    }
                }
                .scaleEffect(shutterPressed ? 0.9 : 1.0)
                .animation(.easeInOut(duration: 0.1), value: shutterPressed)
                .disabled(cameraVM.isCapturing)
            } else {
                // Placeholder to keep torch left-aligned in barcode mode
                Circle()
                    .fill(.clear)
                    .frame(width: 72, height: 72)
            }

            Spacer()

            // Mirror of torch button for visual balance
            Circle()
                .fill(.clear)
                .frame(width: 52, height: 52)
        }
        .padding(.horizontal, 40)
    }
}
