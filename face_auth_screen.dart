import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:face_app/services/face_recognition_service.dart';
import 'package:face_app/services/auth_service.dart';
import 'package:face_app/screens/home/home_screen.dart';
import 'package:audioplayers/audioplayers.dart';
import 'dart:io';
import 'dart:convert';

class FaceAuthScreen extends StatefulWidget {
  const FaceAuthScreen({super.key});

  @override
  State<FaceAuthScreen> createState() => _FaceAuthScreenState();
}

class _FaceAuthScreenState extends State<FaceAuthScreen> {
  late CameraController _controller;
  late Future<void> _initializeControllerFuture;
  final _faceDetector = FaceDetector(
    options: FaceDetectorOptions(
      enableClassification: true,
      enableLandmarks: true,
      enableContours: true,
      enableTracking: true,
    ),
  );
  final _faceRecognitionService = FaceRecognitionService();
  final _authService = AuthService();
  final _audioPlayer = AudioPlayer();
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _initializeControllerFuture = _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    try {
      print('Getting available cameras...');
      final cameras = await availableCameras();
      print('Found ${cameras.length} cameras');
      
      final frontCamera = cameras.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );
      print('Selected camera: ${frontCamera.name} (${frontCamera.lensDirection})');

      _controller = CameraController(
        frontCamera,
        ResolutionPreset.high,
        enableAudio: false,
      );

      print('Initializing camera controller...');
      await _controller.initialize();
      print('Camera controller initialized successfully');
      
      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      print('Error initializing camera: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error initializing camera: $e')),
        );
      }
    }
  }

  Future<void> _takePicture() async {
    if (_isProcessing) return;

    setState(() => _isProcessing = true);

    try {
      print('Starting face capture process...');
      await _initializeControllerFuture;
      
      print('Taking picture...');
      final image = await _controller.takePicture();
      print('Picture taken, path: ${image.path}');
      
      final imageFile = File(image.path);
      final imageSize = await imageFile.length();
      print('Image size: $imageSize bytes');
      
      if (imageSize < 10000) {
        print('Image too small: $imageSize bytes');
        _playSound('failure.mp3');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Image quality too low. Please try again.')),
        );
        return;
      }
      
      print('Processing image for face detection...');
      final inputImage = InputImage.fromFilePath(image.path);
      final faces = await _faceDetector.processImage(inputImage);
      print('Found ${faces.length} faces in captured image');

      if (faces.isEmpty) {
        print('No face detected in captured image');
        _playSound('failure.mp3');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No face detected. Please try again.')),
        );
        return;
      }

      print('Getting current user...');
      final user = await _authService.getCurrentUser();
      if (user == null) {
        print('No user found');
        _playSound('failure.mp3');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('User not found. Please sign in again.')),
        );
        return;
      }

      print('Getting user data...');
      final userData = await _authService.getUserData(user.id);
      print('User data retrieved: ${userData != null ? 'success' : 'null'}');
      if (userData == null || userData['face_image'] == null) {
        print('No face image found in user data');
        _playSound('failure.mp3');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No registered face found. Please sign up first.')),
        );
        return;
      }
      print('Face image found in user data, length: ${userData['face_image'].length}');

      print('Creating temporary file for stored face...');
      final tempDir = await Directory.systemTemp.createTemp();
      final tempFile = File('${tempDir.path}/stored_face.jpg');
      await tempFile.writeAsBytes(base64Decode(userData['face_image']));
      print('Temporary file created at: ${tempFile.path}');

      print('Starting face comparison...');
      final isMatch = await _faceRecognitionService.compareFaces(
        File(image.path),
        tempFile,
      );
      print('Face comparison result: $isMatch');

      if (isMatch) {
        print('Face match successful!');
        _playSound('success.mp3');
        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const HomeScreen()),
        );
      } else {
        print('Face match failed');
        _playSound('failure.mp3');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Face recognition failed. Please try again.')),
        );
      }
    } catch (e) {
      print('Error during face capture process: $e');
      _playSound('failure.mp3');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.toString()}')),
      );
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  Future<void> _playSound(String path) async {
    try {
      await _audioPlayer.play(AssetSource(path));
    } catch (e) {
      print('Error playing sound: $e');
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _faceDetector.close();
    _audioPlayer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Face Authentication'),
      ),
      body: FutureBuilder<void>(
        future: _initializeControllerFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.done) {
            if (snapshot.hasError) {
              print('Camera initialization error: ${snapshot.error}');
              return Center(
                child: Text('Error: ${snapshot.error}'),
              );
            }
            return Stack(
              children: [
                CameraPreview(_controller),
                // Face guide overlay
                Center(
                  child: Container(
                    width: 250,
                    height: 250,
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.white, width: 2),
                      borderRadius: BorderRadius.circular(125),
                    ),
                  ),
                ),
                // Instructions
                Positioned(
                  top: 20,
                  left: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    color: Colors.black54,
                    child: const Text(
                      'Position your face within the circle\nKeep your face centered and still\nEnsure good lighting',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ),
                // Capture button
                Positioned(
                  bottom: 32,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: FloatingActionButton(
                      onPressed: _isProcessing ? null : () {
                        print('Capture button pressed');
                        _takePicture();
                      },
                      child: _isProcessing
                          ? const CircularProgressIndicator()
                          : const Icon(Icons.camera_alt),
                    ),
                  ),
                ),
              ],
            );
          } else {
            return const Center(child: CircularProgressIndicator());
          }
        },
      ),
    );
  }
} 