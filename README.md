# YOLO Object Detection Android App - Homework Assignment

## Overview
In this assignment, you will complete an Android application that performs real-time object detection using a YOLOv8 model with TensorFlow Lite. The base application handles the camera setup and UI components, but key functionality related to model loading, image processing, and detection visualization needs to be implemented.

## Prerequisites
- Basic understanding of Java and Android development
- Familiarity with Android Camera2 API or CameraX
- Basic understanding of TensorFlow Lite
- Access to Android Studio

## Getting Started
1. Clone the starter project repository
2. Download the YOLOv8 TFLite model and place it in the assets folder
3. Review the code in YoloDetectionActivity.java
4. Complete the homework sections marked with TODO comments

## Tasks

### Task 1: Loading the YOLOv8 TFLite Model
Complete the `setupModel()` method to:
- Load the YOLOv8 TFLite model from assets using `FileUtil.loadMappedFile()`
- Initialize the TFLite interpreter with the loaded model
- Load the labels.txt file from assets to get class names

Example of what your implementation should look like:
```java
// Load the YOLOv8 TFLite model from assets
MappedByteBuffer modelBuffer = FileUtil.loadMappedFile(this, "yolov8n.tflite");
Interpreter.Options options = new Interpreter.Options();
tflite = new Interpreter(modelBuffer, options);

// Load the labels file from assets
labels = FileUtil.loadLabels(this, "labels.txt");
```

### Task 2: Processing Images for Detection
In the `YoloAnalyzer` class, complete the `analyze()` method to:
- Convert the ImageProxy to a format TFLite can use (TensorImage)
- Preprocess the image (resize to model input size)
- Run inference with the TFLite interpreter
- Process the output to get bounding boxes, class IDs, and confidence scores
- Convert normalized coordinates to screen coordinates
- Filter by confidence threshold
- Update the overlay view and result text

Your implementation should handle the image rotation correctly and prepare the input tensor in the format expected by the model.

### Task 3: Processing Model Output
Complete the `processModelOutput()` method to:
- Extract boxes, scores, and class IDs from the model output
- Apply non-maximum suppression if needed
- Convert normalized box coordinates to pixel coordinates
- Create DetectionResult objects for each detection

This is the core logic that transforms the raw model output into meaningful detection results.

## Model Output Format
The YOLOv8 TFLite model outputs a tensor with shape [1, 84, 8400] where:
- 84 = 4 (bounding box coordinates) + 80 (class probabilities for COCO dataset)
- 8400 = number of predicted boxes

For each of the 8400 predictions:
- The first 4 values are the bounding box coordinates in format [x_center, y_center, width, height], normalized to [0, 1]
- The remaining 80 values are class probabilities

## Expected Output
When implemented correctly, the app should:
1. Display a live camera feed
2. Show bounding boxes around detected objects
3. Display class labels and confidence scores
4. Update the detection results text at the bottom of the screen

## Resources
- [TensorFlow Lite Android Documentation](https://www.tensorflow.org/lite/guide/android)
- [CameraX Documentation](https://developer.android.com/training/camerax)
- [Ultralytics YOLOv8 Documentation](https://docs.ultralytics.com/)
- [TensorFlow Lite Model Export in YOLOv8](https://docs.ultralytics.com/integrations/tflite/)
