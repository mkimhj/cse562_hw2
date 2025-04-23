import UIKit
import AVFoundation
import CoreML
import Vision

class SquareCameraViewController: UIViewController {
    
    // MARK: - Properties
    private let captureSession = AVCaptureSession()
    private var previewLayer: AVCaptureVideoPreviewLayer?
    private let videoOutput = AVCaptureVideoDataOutput()
    private let sessionQueue = DispatchQueue(label: "sessionQueue")
    
    // YOLO model properties
    private var yoloModel: VNCoreMLModel?
    private var detectionOverlay = CALayer()
    private let modelInputSize = 640 // YOLOv8n input size
    
    // Store camera and display orientations
    private var videoOrientation: AVCaptureVideoOrientation = .portrait
    private var currentDeviceOrientation: UIDeviceOrientation = .portrait
    
    private let previewView: UIView = {
        let view = UIView()
        view.backgroundColor = .black
        view.translatesAutoresizingMaskIntoConstraints = false
        view.contentMode = .scaleAspectFill
        view.clipsToBounds = true
        return view
    }()
    
    private let resultLabel: UILabel = {
        let label = UILabel()
        label.textColor = .white
        label.backgroundColor = UIColor.black.withAlphaComponent(0.7)
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        label.text = "No detections"
        label.textAlignment = .center
        label.font = UIFont.systemFont(ofSize: 14)
        return label
    }()
    
    // MARK: - Lifecycle Methods
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupYOLOModel()
        setupCamera()
        
        // Setup device orientation notifications
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(deviceOrientationDidChange),
            name: UIDevice.orientationDidChangeNotification,
            object: nil
        )
        UIDevice.current.beginGeneratingDeviceOrientationNotifications()
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
        UIDevice.current.endGeneratingDeviceOrientationNotifications()
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
        view.addSubview(resultLabel)
        
        // Make preview view square and centered
        NSLayoutConstraint.activate([
            previewView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            previewView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            previewView.widthAnchor.constraint(equalTo: view.widthAnchor),
            previewView.heightAnchor.constraint(equalTo: previewView.widthAnchor), // Makes it square
            
            resultLabel.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20),
            resultLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            resultLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            resultLabel.heightAnchor.constraint(greaterThanOrEqualToConstant: 40)
        ])
        
        // Setup detection overlay for drawing bounding boxes
        detectionOverlay.name = "DetectionOverlay"
        detectionOverlay.frame = previewView.bounds
        detectionOverlay.masksToBounds = true
        previewView.layer.addSublayer(detectionOverlay)
    }
    
    private func setupYOLOModel() {
        do {
            // Load the YOLOv8 model
            let config = MLModelConfiguration()
            config.computeUnits = .all
            
            // TODO: Assign 'forResource' with the name of your model from colab
            
            // Try different ways to load the model
            if let modelURL = Bundle.main.url(forResource: "", withExtension: "mlmodelc") {
                // Try to load model from mlmodelc directory
                let coreMLModel = try MLModel(contentsOf: modelURL, configuration: config)
                yoloModel = try VNCoreMLModel(for: coreMLModel)
                print("Model loaded from mlmodelc")
                
            } else if let packageURL = Bundle.main.url(forResource: "", withExtension: "mlpackage") {
                // Try to compile and load model from mlpackage
                let compiledModelURL = try MLModel.compileModel(at: packageURL)
                let coreMLModel = try MLModel(contentsOf: compiledModelURL)
                yoloModel = try VNCoreMLModel(for: coreMLModel)
                print("Model loaded from mlpackage")
                
            } else {
                print("Failed to find model in bundle")
            }
        } catch {
            print("Error loading YOLO model: \(error)")
        }
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
            
            // Set initial video orientation
            if let connection = self.videoOutput.connection(with: .video) {
                if connection.isVideoOrientationSupported {
                    connection.videoOrientation = .portrait
                    self.videoOrientation = .portrait
                }
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
        
        // Important: Add the preview layer BELOW the detection overlay
        previewView.layer.insertSublayer(previewLayer, at: 0)
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
        detectionOverlay.frame = previewView.bounds
    }
    
    // MARK: - Orientation Handling
    @objc private func deviceOrientationDidChange() {
        guard let connection = videoOutput.connection(with: .video),
              connection.isVideoOrientationSupported else {
            return
        }
        
        let deviceOrientation = UIDevice.current.orientation
        guard deviceOrientation.isPortrait || deviceOrientation.isLandscape else {
            return
        }
        
        currentDeviceOrientation = deviceOrientation
        
        // Update video orientation based on device orientation
        switch deviceOrientation {
        case .portrait:
            connection.videoOrientation = .portrait
            videoOrientation = .portrait
        case .portraitUpsideDown:
            connection.videoOrientation = .portraitUpsideDown
            videoOrientation = .portraitUpsideDown
        case .landscapeLeft:
            connection.videoOrientation = .landscapeRight
            videoOrientation = .landscapeRight
        case .landscapeRight:
            connection.videoOrientation = .landscapeLeft
            videoOrientation = .landscapeLeft
        default:
            break
        }
    }
    
    // MARK: - YOLO Detection Methods
    private func detectObjects(in pixelBuffer: CVPixelBuffer) {
        guard let yoloModel = self.yoloModel else {
            print("YOLO model not loaded")
            return
        }
        
        // TODO: Create Vision request with the YOLO model, use VNCoreMLRequest, and pass the request into processDetectionResults
        // FILL IN HERE
        // END TODO
       
        // Configure the request to use the input image without modification
        request.imageCropAndScaleOption = .scaleFit
        
        // Create a handler for processing the request
        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: .up, options: [:])
        
        do {
            try handler.perform([request])
        } catch {
            print("Failed to perform detection: \(error)")
        }
    }
    
    private func processDetectionResults(request: VNRequest) {
        // TODO: Extract VNRecognizedObjectObservation results from the request, and filter results by confidence threshold (filteredResults)
        // FILL IN HERE
        // END TODO
        
        // Update UI on main thread
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            // Clear previous detections
            self.detectionOverlay.sublayers?.forEach { $0.removeFromSuperlayer() }
            
            // Debug info
            print("Drawing \(filteredResults.count) detections")
            
            // Get the view dimensions for proper coordinate conversion
            let viewWidth = self.previewView.bounds.width
            let viewHeight = self.previewView.bounds.height
            
            // Draw new detections
            for observation in filteredResults {
                // Get the top classification
                guard let topLabel = observation.labels.first else { continue }
                
                // Get normalized bounding box (0-1 values)
                let boundingBox = observation.boundingBox
                
                // Convert to view coordinates - this is the key part from the Ultralytics app
                let convertedBox = self.convertNormalizedBoundingBox(
                    boundingBox,
                    toViewWithWidth: viewWidth,
                    height: viewHeight
                )
                
                // Debug info
                print("Drawing box at \(convertedBox) for \(topLabel.identifier)")
                
                // Draw the detection
                self.drawDetection(
                    convertedBox,
                    label: "\(topLabel.identifier) \(Int(topLabel.confidence * 100))%",
                    color: .green
                )
            }
            
            // Update result label
            if filteredResults.isEmpty {
                self.resultLabel.text = "No objects detected"
            } else {
                let detectionTexts = filteredResults.compactMap { observation -> String? in
                    guard let label = observation.labels.first else { return nil }
                    return "\(label.identifier): \(Int(label.confidence * 100))%"
                }
                self.resultLabel.text = detectionTexts.joined(separator: ", ")
            }
        }
    }
    
    private func convertNormalizedBoundingBox(_ boundingBox: CGRect, toViewWithWidth width: CGFloat, height: CGFloat) -> CGRect {
        // Using Ultralytics' approach for coordinate conversion
        // Note: Vision provides normalized coordinates (0-1) with origin at bottom-left
        
        // Calculate dimensions and positions
        let boxWidth = boundingBox.width * width
        let boxHeight = boundingBox.height * height
        
        // x,y in Vision framework are the center of the box (not top-left)
        let boxX = boundingBox.minX * width
        let boxY = (1 - boundingBox.maxY) * height // Flip Y coordinates for UIKit
        
        // Create rect in view coordinates (top-left origin)
        return CGRect(x: boxX, y: boxY, width: boxWidth, height: boxHeight)
    }
    
    private func drawDetection(_ rect: CGRect, label: String, color: UIColor) {
        // Create box for the detection
        let boxLayer = CALayer()
        boxLayer.frame = rect
        boxLayer.borderWidth = 3.0 // Thicker border for visibility
        boxLayer.borderColor = color.cgColor
        boxLayer.cornerRadius = 4.0
        
        // Create label for the detection
        let textLayer = CATextLayer()
        textLayer.string = label
        textLayer.fontSize = 14
        textLayer.foregroundColor = UIColor.white.cgColor
        textLayer.backgroundColor = color.withAlphaComponent(0.7).cgColor
        textLayer.cornerRadius = 4.0
        textLayer.masksToBounds = true
        textLayer.alignmentMode = .center
        textLayer.frame = CGRect(x: rect.minX, y: max(0, rect.minY - 20), width: rect.width, height: 20)
        
        // Add to overlay
        detectionOverlay.addSublayer(boxLayer)
        detectionOverlay.addSublayer(textLayer)
    }
}

// MARK: - AVCaptureVideoDataOutputSampleBufferDelegate
extension SquareCameraViewController: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        // Process camera output
        // 1. Extract CMSampleBuffer to CVPixelBuffer
        // 2. Call detectObjects(in:) with the pixel buffer
        // TODO: Implement sample buffer processing
    }
}
