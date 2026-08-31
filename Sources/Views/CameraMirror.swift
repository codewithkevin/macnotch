import SwiftUI
import AVFoundation

/// Owns an `AVCaptureSession` for the mirror widget. The camera only runs while
/// `setActive(true)` — the widget ties that to the panel being open.
@MainActor
final class CameraMirrorController: ObservableObject {
    enum State { case idle, denied, running }

    @Published private(set) var state: State = .idle
    let session = AVCaptureSession()

    private var configured = false
    private let queue = DispatchQueue(label: "io.macnotch.camera")

    func setActive(_ active: Bool) {
        guard active else {
            queue.async { [session] in if session.isRunning { session.stopRunning() } }
            if state == .running { state = .idle }
            return
        }
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            configureAndRun()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                Task { @MainActor in granted ? self?.configureAndRun() : (self?.state = .denied) }
            }
        default:
            state = .denied
        }
    }

    private func configureAndRun() {
        if !configured {
            session.beginConfiguration()
            session.sessionPreset = .medium
            if let cam = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front)
                ?? AVCaptureDevice.default(for: .video),
               let input = try? AVCaptureDeviceInput(device: cam),
               session.canAddInput(input) {
                session.addInput(input)
            }
            session.commitConfiguration()
            configured = true
        }
        queue.async { [session] in if !session.isRunning { session.startRunning() } }
        state = .running
    }
}

/// SwiftUI wrapper around an `AVCaptureVideoPreviewLayer`, mirrored like FaceTime.
struct CameraPreview: NSViewRepresentable {
    let session: AVCaptureSession

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        view.wantsLayer = true
        let preview = AVCaptureVideoPreviewLayer(session: session)
        preview.videoGravity = .resizeAspectFill
        preview.connection?.automaticallyAdjustsVideoMirroring = false
        preview.connection?.isVideoMirrored = true
        view.layer = preview
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        (nsView.layer as? AVCaptureVideoPreviewLayer)?.frame = nsView.bounds
    }
}
