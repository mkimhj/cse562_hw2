import UIKit
import AVFoundation

class SquareCameraViewController: UIViewController {
    
    // MARK: - Properties
    private let captureSession = AVCaptureSession()
    private var previewLayer: AVCaptureVideoPreviewLayer?
    private let videoOutput = AVCaptureVideoDataOutput()
    private let sessionQueue = DispatchQueue(label: "sessionQueue")
    
    private let previewView: UIView = {
        let view = UIView()
        view.backgroundColor = .black
        view.translatesAutoresizingMaskIntoConstraints = false
        view.contentMode = .scaleAspectFill
        view.clipsToBounds = true
        return view
    }()
    
    // MARK: - Lifecycle Methods
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupCamera()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        startSession()
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        stopSession()
    }
    
    // MARK: - Setup Methods
    private func setupUI() {
        view.backgroundColor = .black
        
        // Add the preview view
        view.addSubview(previewView)
        
        // Make preview view square and centered
        NSLayoutConstraint.activate([
            previewView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            previewView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            previewView.widthAnchor.constraint(equalTo: view.widthAnchor),
            previewView.heightAnchor.constraint(equalTo: previewView.widthAnchor) // Makes it square
        ])
    }
    
    private func setupCamera() {
        // Configure capture session
        sessionQueue.async { [weak self] in
            guard let self = self else { return }
            
            self.captureSession.beginConfiguration()
            
            // Set session preset
            if self.captureSession.canSetSessionPreset(.photo) {
                self.captureSession.sessionPreset = .photo
            }
            
            // Setup camera input
            guard let backCamera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
                  let input = try? AVCaptureDeviceInput(device: backCamera) else {
                print("Failed to get camera input")
                return
            }
            
            if self.captureSession.canAddInput(input) {
                self.captureSession.addInput(input)
            }
            
            // Setup video output
            self.videoOutput.videoSettings = [(kCVPixelBufferPixelFormatTypeKey as String): Int(kCVPixelFormatType_32BGRA)]
            self.videoOutput.setSampleBufferDelegate(self, queue: DispatchQueue(label: "videoQueue"))
            
            if self.captureSession.canAddOutput(self.videoOutput) {
                self.captureSession.addOutput(self.videoOutput)
            }
            
            // Setup preview layer on main thread
            DispatchQueue.main.async {
                self.setupPreviewLayer()
            }
            
            self.captureSession.commitConfiguration()
        }
    }
    
    private func setupPreviewLayer() {
        let previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        previewLayer.videoGravity = .resizeAspectFill
        previewLayer.frame = previewView.bounds
        previewView.layer.addSublayer(previewLayer)
        self.previewLayer = previewLayer
    }
    
    // MARK: - Session Control
    private func startSession() {
        sessionQueue.async { [weak self] in
            self?.captureSession.startRunning()
        }
    }
    
    private func stopSession() {
        sessionQueue.async { [weak self] in
            self?.captureSession.stopRunning()
        }
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer?.frame = previewView.bounds
    }
}

// MARK: - AVCaptureVideoDataOutputSampleBufferDelegate
extension SquareCameraViewController: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        // Here is where you'll process the camera frames for YOLO
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        
        // For now, we're just getting the frame, but we'll later pass this to YOLO
        // Example of how to process:
        
        // 1. Convert the image buffer to a CIImage
        // let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        
        // 2. Create a square crop from the center of the image
        // let squareSize = min(CVPixelBufferGetWidth(pixelBuffer), CVPixelBufferGetHeight(pixelBuffer))
        // let centerX = CVPixelBufferGetWidth(pixelBuffer) / 2
        // let centerY = CVPixelBufferGetHeight(pixelBuffer) / 2
        // let cropRect = CGRect(x: centerX - squareSize/2, y: centerY - squareSize/2, width: squareSize, height: squareSize)
        // let croppedImage = ciImage.cropped(to: cropRect)
        
        // 3. Resize to the YOLO input size (example: 416x416)
        // let scaleX = 416.0 / CGFloat(squareSize)
        // let scaleY = 416.0 / CGFloat(squareSize)
        // let resizedImage = croppedImage.transformed(by: CGAffineTransform(scaleX: scaleX, scaleY: scaleY))
        
        // 4. Convert to pixel buffer or other format needed by your YOLO model
        
        // You'll implement these steps when you integrate your YOLO model
    }
}
