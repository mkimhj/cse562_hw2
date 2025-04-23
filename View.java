package com.example.yolodetection;

import android.Manifest;
import android.content.Context;
import android.content.pm.PackageManager;
import android.graphics.Canvas;
import android.graphics.Color;
import android.graphics.Matrix;
import android.graphics.Paint;
import android.graphics.RectF;
import android.media.Image;
import android.os.Bundle;
import android.util.Log;
import android.util.Size;
import android.view.Surface;
import android.view.TextureView;
import android.view.ViewGroup;
import android.widget.TextView;
import android.widget.Toast;

import androidx.annotation.NonNull;
import androidx.appcompat.app.AppCompatActivity;
import androidx.camera.core.CameraSelector;
import androidx.camera.core.ImageAnalysis;
import androidx.camera.core.ImageProxy;
import androidx.camera.core.Preview;
import androidx.camera.lifecycle.ProcessCameraProvider;
import androidx.core.app.ActivityCompat;
import androidx.core.content.ContextCompat;
import androidx.lifecycle.LifecycleOwner;

import com.google.common.util.concurrent.ListenableFuture;

import org.tensorflow.lite.Interpreter;
import org.tensorflow.lite.support.common.FileUtil;
import org.tensorflow.lite.support.image.ImageProcessor;
import org.tensorflow.lite.support.image.TensorImage;
import org.tensorflow.lite.support.image.ops.ResizeOp;

import java.io.IOException;
import java.nio.ByteBuffer;
import java.nio.MappedByteBuffer;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.List;
import java.util.concurrent.ExecutionException;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;

public class YoloDetectionActivity extends AppCompatActivity {
    private static final String TAG = "YoloDetectionActivity";
    private static final int REQUEST_CODE_PERMISSIONS = 10;
    private static final String[] REQUIRED_PERMISSIONS = {Manifest.permission.CAMERA};

    private TextureView viewFinder;
    private TextView resultTextView;
    private OverlayView overlayView;
    
    private ExecutorService cameraExecutor;
    private Interpreter tflite;
    private int modelInputSize = 640; // YOLOv8n input size
    private List<String> labels;
    
    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.activity_yolo_detection);
        
        viewFinder = findViewById(R.id.view_finder);
        resultTextView = findViewById(R.id.result_text_view);
        overlayView = findViewById(R.id.overlay_view);
        
        // Request camera permissions
        if (allPermissionsGranted()) {
            setupCamera();
        } else {
            ActivityCompat.requestPermissions(
                    this, REQUIRED_PERMISSIONS, REQUEST_CODE_PERMISSIONS);
        }
        
        // Setup TensorFlow Lite model
        setupModel();
        
        cameraExecutor = Executors.newSingleThreadExecutor();
    }

    private void setupCamera() {
        ListenableFuture<ProcessCameraProvider> cameraProviderFuture = 
                ProcessCameraProvider.getInstance(this);
        
        cameraProviderFuture.addListener(() -> {
            try {
                // Camera provider is now guaranteed to be available
                ProcessCameraProvider cameraProvider = cameraProviderFuture.get();
                
                // Set up the preview use case
                Preview preview = new Preview.Builder().build();
                preview.setSurfaceProvider(viewFinder.getSurfaceProvider());
                
                // Set up the image analyzer use case
                ImageAnalysis imageAnalysis = new ImageAnalysis.Builder()
                        .setTargetResolution(new Size(640, 640))
                        .setBackpressureStrategy(ImageAnalysis.STRATEGY_KEEP_ONLY_LATEST)
                        .build();
                
                imageAnalysis.setAnalyzer(cameraExecutor, new YoloAnalyzer());
                
                // Select back camera as default
                CameraSelector cameraSelector = CameraSelector.DEFAULT_BACK_CAMERA;
                
                // Unbind use cases before rebinding
                cameraProvider.unbindAll();
                
                // Bind use cases to camera
                cameraProvider.bindToLifecycle(
                        (LifecycleOwner) this, cameraSelector, preview, imageAnalysis);
                
            } catch (ExecutionException | InterruptedException e) {
                Log.e(TAG, "Use case binding failed", e);
            }
        }, ContextCompat.getMainExecutor(this));
    }
    
    private void setupModel() {
        try {
            // TODO: Load the YOLOv8 TFLite model from assets
            // Use FileUtil.loadMappedFile() to load the model file
            // Initialize the TFLite interpreter
            
            // TODO: Load the labels.txt file from assets
            // Parse the labels file to get class names
            
        } catch (IOException e) {
            Log.e(TAG, "Error loading model", e);
            Toast.makeText(this, "Could not load YOLO model", Toast.LENGTH_SHORT).show();
            finish();
        }
    }
    
    @Override
    public void onRequestPermissionsResult(int requestCode, @NonNull String[] permissions, 
                                          @NonNull int[] grantResults) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults);
        if (requestCode == REQUEST_CODE_PERMISSIONS) {
            if (allPermissionsGranted()) {
                setupCamera();
            } else {
                Toast.makeText(this, "Permissions not granted by the user.", Toast.LENGTH_SHORT).show();
                finish();
            }
        }
    }
    
    private boolean allPermissionsGranted() {
        for (String permission : REQUIRED_PERMISSIONS) {
            if (ContextCompat.checkSelfPermission(this, permission) != 
                    PackageManager.PERMISSION_GRANTED) {
                return false;
            }
        }
        return true;
    }
    
    @Override
    protected void onDestroy() {
        super.onDestroy();
        if (cameraExecutor != null) {
            cameraExecutor.shutdown();
        }
        if (tflite != null) {
            tflite.close();
        }
    }
    
    // Custom view for drawing detection results
    public static class OverlayView extends ViewGroup {
        private List<DetectionResult> results = new ArrayList<>();
        private final Paint boxPaint;
        private final Paint textPaint;
        private final Paint textBackgroundPaint;
        
        public OverlayView(Context context) {
            super(context);
            setWillNotDraw(false);
            
            boxPaint = new Paint();
            boxPaint.setColor(Color.GREEN);
            boxPaint.setStyle(Paint.Style.STROKE);
            boxPaint.setStrokeWidth(4.0f);
            
            textPaint = new Paint();
            textPaint.setColor(Color.WHITE);
            textPaint.setTextSize(32.0f);
            
            textBackgroundPaint = new Paint();
            textBackgroundPaint.setColor(Color.GREEN);
            textBackgroundPaint.setAlpha(180);
            textBackgroundPaint.setStyle(Paint.Style.FILL);
        }
        
        public void setResults(List<DetectionResult> results) {
            this.results = results;
            invalidate();
        }
        
        @Override
        protected void onDraw(Canvas canvas) {
            super.onDraw(canvas);
            
            for (DetectionResult result : results) {
                RectF boundingBox = result.boundingBox;
                String label = result.label + " " + (int)(result.confidence * 100) + "%";
                
                // Draw bounding box
                canvas.drawRect(boundingBox, boxPaint);
                
                // Draw text background
                float textWidth = textPaint.measureText(label);
                canvas.drawRect(
                        boundingBox.left,
                        boundingBox.top - 40,
                        boundingBox.left + textWidth + 8,
                        boundingBox.top,
                        textBackgroundPaint);
                
                // Draw label text
                canvas.drawText(
                        label,
                        boundingBox.left + 4,
                        boundingBox.top - 12,
                        textPaint);
            }
        }
        
        @Override
        protected void onLayout(boolean changed, int left, int top, int right, int bottom) {
            // Do nothing as we don't have child views
        }
    }
    
    // Detection result data class
    public static class DetectionResult {
        public RectF boundingBox;
        public String label;
        public float confidence;
        
        public DetectionResult(RectF boundingBox, String label, float confidence) {
            this.boundingBox = boundingBox;
            this.label = label;
            this.confidence = confidence;
        }
    }
    
    // Image analyzer for YOLO detection
    private class YoloAnalyzer implements ImageAnalysis.Analyzer {
        private final ImageProcessor imageProcessor;
        
        public YoloAnalyzer() {
            // Set up image processor for input preprocessing
            imageProcessor = new ImageProcessor.Builder()
                    .add(new ResizeOp(modelInputSize, modelInputSize, ResizeOp.ResizeMethod.BILINEAR))
                    .build();
        }
        
        @Override
        public void analyze(@NonNull ImageProxy imageProxy) {
            if (tflite == null) {
                imageProxy.close();
                return;
            }
            
            try {
                // TODO: Process the image and run the YOLO model
                // 1. Convert the ImageProxy to a format TFLite can use (TensorImage)
                // 2. Preprocess the image (resize to model input size)
                // 3. Run inference with the TFLite interpreter
                // 4. Process the output to get bounding boxes, class IDs, and confidence scores
                // 5. Convert normalized coordinates to screen coordinates
                // 6. Filter by confidence threshold
                // 7. Update the overlay view and result text
                
            } catch (Exception e) {
                Log.e(TAG, "Error processing image", e);
            } finally {
                imageProxy.close();
            }
        }
        
        private List<DetectionResult> processModelOutput(float[][][] output) {
            // TODO: Process the raw model output
            // 1. Extract boxes, scores, and class IDs from the model output
            // 2. Apply non-maximum suppression if needed
            // 3. Convert normalized box coordinates to pixel coordinates
            // 4. Create DetectionResult objects for each detection
            
            return new ArrayList<>(); // Replace with actual implementation
        }
        
        private String getDetectionSummary(List<DetectionResult> results) {
            if (results.isEmpty()) {
                return "No objects detected";
            }
            
            StringBuilder sb = new StringBuilder();
            for (int i = 0; i < results.size(); i++) {
                DetectionResult result = results.get(i);
                sb.append(result.label)
                  .append(": ")
                  .append((int) (result.confidence * 100))
                  .append("%");
                
                if (i < results.size() - 1) {
                    sb.append(", ");
                }
            }
            
            return sb.toString();
        }
    }
}
