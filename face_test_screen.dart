import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:provider/provider.dart';
import 'package:face_app/providers/auth_provider.dart';
import 'package:face_app/services/face_recognition_service.dart';
import 'package:face_app/services/audio_service.dart';
import 'dart:io';
import 'dart:convert';

class FaceTestScreen extends StatefulWidget {
  const FaceTestScreen({super.key});

  @override
  State<FaceTestScreen> createState() => _FaceTestScreenState();
}

class _FaceTestScreenState extends State<FaceTestScreen> {
  final _faceRecognitionService = FaceRecognitionService();
  final _audioService = AudioService();
  late CameraController _cameraController;
  bool _isInitialized = false;
  bool _isProcessing = false;
  bool _isTakingPhoto = false;

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    try {
      final cameras = await availableCameras();
      // Trouver la caméra frontale
      final frontCamera = cameras.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first, // Fallback sur la première caméra si pas de frontale
      );

      _cameraController = CameraController(
        frontCamera,
        ResolutionPreset.medium,
        enableAudio: false,
      );

      await _cameraController.initialize();
      setState(() {
        _isInitialized = true;
      });
    } catch (e) {
      print('Error initializing camera: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur d\'initialisation de la caméra: $e')),
        );
      }
    }
  }

  Future<void> _takePicture() async {
    if (!_isInitialized) return;

    setState(() => _isTakingPhoto = true);

    try {
      final image = await _cameraController.takePicture();
      setState(() {
        _isTakingPhoto = false;
      });
      if (mounted) {
        await _compareFaces(File(image.path));
      }
    } catch (e) {
      setState(() => _isTakingPhoto = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur lors de la prise de photo: $e')),
      );
    }
  }

  Future<void> _compareFaces(File testImage) async {
    setState(() => _isProcessing = true);

    try {
      // Get the stored image base64
      final storedImageBase64 = await context.read<AuthProvider>().getUserImageBase64();
      if (storedImageBase64 == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Aucune image de référence trouvée')),
        );
        return;
      }

      // Convert base64 to file
      final bytes = base64Decode(storedImageBase64);
      final tempDir = Directory.systemTemp;
      final storedImageFile = File('${tempDir.path}/stored_image.jpg');
      await storedImageFile.writeAsBytes(bytes);

      // Compare faces
      final isMatch = await _faceRecognitionService.compareFaces(
        testImage,
        storedImageFile,
      );

      if (isMatch) {
        await _audioService.playSuccessSound();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Reconnaissance faciale réussie !')),
        );
      } else {
        await _audioService.playFailureSound();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Reconnaissance faciale échouée')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur: $e')),
      );
      await _audioService.playFailureSound();
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  @override
  void dispose() {
    _cameraController.dispose();
    _faceRecognitionService.dispose();
    _audioService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Test de reconnaissance faciale'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Prenez une photo de votre visage',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            const Text(
              'Cette photo sera comparée avec votre photo de référence',
              style: TextStyle(
                color: Colors.grey,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            if (_isInitialized)
              Container(
                height: 300,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Transform.scale(
                    scale: 1.0,
                    child: CameraPreview(_cameraController),
                  ),
                ),
              )
            else
              Container(
                height: 300,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Center(
                  child: CircularProgressIndicator(),
                ),
              ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _isTakingPhoto || _isProcessing ? null : _takePicture,
              icon: const Icon(Icons.camera_alt),
              label: const Text('Prendre une photo'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }
} 