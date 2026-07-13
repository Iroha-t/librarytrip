import SwiftUI
import AVFoundation

/// ISBN バーコード（EAN-13, 978/979 で始まる）をカメラで読み取るシート
///
/// 本の裏表紙には 2 段バーコードが印刷されている:
///   上段 978/979 始まり → ISBN（これを読む）
///   下段 191/192 始まり → 日本図書コード（価格など・無視する）
struct BarcodeScannerView: View {
    let onScan: (String) -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var permissionDenied = false

    var body: some View {
        NavigationStack {
            ZStack {
                if permissionDenied {
                    permissionDeniedView
                } else {
                    ScannerPreview { isbn in
                        onScan(isbn)
                        dismiss()
                    }
                    .ignoresSafeArea()

                    scanGuideOverlay
                }
            }
            .navigationTitle("バーコードを読み取る")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("閉じる") { dismiss() }
                        .foregroundColor(.toshoGreen)
                }
            }
            .task {
                let status = AVCaptureDevice.authorizationStatus(for: .video)
                switch status {
                case .notDetermined:
                    let granted = await AVCaptureDevice.requestAccess(for: .video)
                    permissionDenied = !granted
                case .denied, .restricted:
                    permissionDenied = true
                default:
                    break
                }
            }
        }
    }

    private var scanGuideOverlay: some View {
        VStack {
            Spacer()
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(Color.toshoGreen, lineWidth: 3)
                .frame(width: 280, height: 130)
                .background(Color.clear)
            Text("本の裏表紙の上段バーコード\n（978 で始まる番号）を枠内に収めてください")
                .font(.footnote)
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(Color.black.opacity(0.55))
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .padding(.top, 14)
            Spacer()
        }
    }

    private var permissionDeniedView: some View {
        VStack(spacing: 14) {
            Image(systemName: "camera.fill")
                .font(.system(size: 44))
                .foregroundColor(.toshoSubtext)
            Text("カメラへのアクセスが許可されていません")
                .font(.headline)
                .foregroundColor(.toshoText)
            Text("設定アプリからカメラの使用を許可してください")
                .font(.subheadline)
                .foregroundColor(.toshoSubtext)
                .multilineTextAlignment(.center)
            Button {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            } label: {
                Text("設定を開く")
                    .font(.subheadline.bold())
                    .foregroundColor(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(Color.toshoGreen)
                    .clipShape(Capsule())
            }
        }
        .padding(32)
    }
}

// MARK: - AVFoundation カメラプレビュー

private struct ScannerPreview: UIViewControllerRepresentable {
    let onScan: (String) -> Void

    func makeUIViewController(context: Context) -> ScannerViewController {
        let vc = ScannerViewController()
        vc.onScan = onScan
        return vc
    }

    func updateUIViewController(_ uiViewController: ScannerViewController, context: Context) {}
}

final class ScannerViewController: UIViewController, AVCaptureMetadataOutputObjectsDelegate {
    var onScan: ((String) -> Void)?

    private let session = AVCaptureSession()
    private var previewLayer: AVCaptureVideoPreviewLayer?
    private var didScan = false

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black

        guard let device = AVCaptureDevice.default(for: .video),
              let input = try? AVCaptureDeviceInput(device: device),
              session.canAddInput(input)
        else { return }
        session.addInput(input)

        let output = AVCaptureMetadataOutput()
        guard session.canAddOutput(output) else { return }
        session.addOutput(output)
        output.setMetadataObjectsDelegate(self, queue: .main)
        output.metadataObjectTypes = [.ean13]

        let layer = AVCaptureVideoPreviewLayer(session: session)
        layer.videoGravity = .resizeAspectFill
        view.layer.addSublayer(layer)
        previewLayer = layer
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer?.frame = view.bounds
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        if !session.isRunning {
            let session = self.session
            DispatchQueue.global(qos: .userInitiated).async {
                session.startRunning()
            }
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        if session.isRunning {
            session.stopRunning()
        }
    }

    func metadataOutput(
        _ output: AVCaptureMetadataOutput,
        didOutput metadataObjects: [AVMetadataObject],
        from connection: AVCaptureConnection
    ) {
        guard !didScan else { return }
        for object in metadataObjects {
            guard let code = (object as? AVMetadataMachineReadableCodeObject)?.stringValue else { continue }
            // ISBN は 978 / 979 で始まる EAN-13 のみ（下段の価格コード 191/192 は無視）
            guard code.hasPrefix("978") || code.hasPrefix("979") else { continue }
            didScan = true
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            onScan?(code)
            break
        }
    }
}
