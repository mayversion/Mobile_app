import 'dart:io';
import 'dart:math';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

class FaceRecognitionService {
  final _faceDetector = FaceDetector(
    options: FaceDetectorOptions(
      enableClassification: true,
      enableLandmarks: true,
      enableContours: true,
      enableTracking: true,
      minFaceSize: 0.15,
    ),
  );

  Future<bool> compareFaces(File image1, File image2) async {
    try {
      print('Starting face comparison...');
      
      // Convertir les fichiers en InputImage
      final inputImage1 = InputImage.fromFile(image1);
      final inputImage2 = InputImage.fromFile(image2);
      
      print('Processing first image...');
      final faces1 = await _faceDetector.processImage(inputImage1);
      print('Processing second image...');
      final faces2 = await _faceDetector.processImage(inputImage2);
      
      if (faces1.isEmpty || faces2.isEmpty) {
        print('No face detected in one or both images');
        return false;
      }
      
      final face1 = faces1.first;
      final face2 = faces2.first;
      
      // Calculer la similarité basée sur les caractéristiques du visage
      double similarity = 0.0;
      
      // Comparer la taille relative du visage
      final size1 = face1.boundingBox.width * face1.boundingBox.height;
      final size2 = face2.boundingBox.width * face2.boundingBox.height;
      final sizeRatio = size1 / size2;
      similarity += (1 - (sizeRatio - 1).abs()) * 0.2;
      
      // Comparer les angles de la tête
      if (face1.headEulerAngleY != null && face2.headEulerAngleY != null) {
        final angleDiff = (face1.headEulerAngleY! - face2.headEulerAngleY!).abs();
        similarity += (1 - (angleDiff / 45)) * 0.2;
      }
      
      // Comparer les probabilités d'ouverture des yeux
      if (face1.leftEyeOpenProbability != null && face2.leftEyeOpenProbability != null &&
          face1.rightEyeOpenProbability != null && face2.rightEyeOpenProbability != null) {
        final leftEyeDiff = (face1.leftEyeOpenProbability! - face2.leftEyeOpenProbability!).abs();
        final rightEyeDiff = (face1.rightEyeOpenProbability! - face2.rightEyeOpenProbability!).abs();
        similarity += (1 - (leftEyeDiff + rightEyeDiff) / 2) * 0.2;
      }
      
      // Comparer les points de repère faciaux si disponibles
      if (face1.landmarks.isNotEmpty && face2.landmarks.isNotEmpty) {
        final landmarks1 = face1.landmarks;
        final landmarks2 = face2.landmarks;
        
        double landmarkSimilarity = 0.0;
        for (var i = 0; i < landmarks1.length; i++) {
          if (i < landmarks2.length) {
            final point1 = landmarks1[i]?.position;
            final point2 = landmarks2[i]?.position;
            if (point1 != null && point2 != null) {
              final distance = sqrt(pow(point1.x - point2.x, 2) + pow(point1.y - point2.y, 2));
              landmarkSimilarity += 1 - (distance / 100); // Normaliser la distance
            }
          }
        }
        similarity += (landmarkSimilarity / landmarks1.length) * 0.4;
      }
      
      print('Final similarity score: $similarity');
      return similarity > 0.3;
    } catch (e) {
      print('Error comparing faces: $e');
      return false;
    }
  }

  Future<bool> checkFaceQuality(File imageFile) async {
    try {
      final inputImage = InputImage.fromFile(imageFile);
      final faces = await _faceDetector.processImage(inputImage);

      if (faces.isEmpty) {
        print('No face detected in the image');
        return false;
      }

      final face = faces.first;
      print('Face detected: ${face.boundingBox}');

      // Vérifier la taille du visage (au moins 15% de l'image)
      final faceSize = face.boundingBox.width * face.boundingBox.height;
      final imageSize = await imageFile.length();
      final faceRatio = faceSize / (imageSize * 0.1); // Estimation approximative
      
      print('Face ratio: $faceRatio');
      if (faceRatio < 0.15) {
        print('Face too small in image');
        return false;
      }

      // Vérifier l'inclinaison (plus permissif)
      if (face.headEulerAngleY != null) {
        final angle = face.headEulerAngleY!.abs();
        print('Head angle: $angle');
        if (angle > 25) { // Augmenté de 20 à 25
          print('Face angle too extreme');
          return false;
        }
      }

      // Vérifier l'ouverture des yeux (plus permissif)
      if (face.leftEyeOpenProbability != null && face.rightEyeOpenProbability != null) {
        final leftEyeOpen = face.leftEyeOpenProbability!;
        final rightEyeOpen = face.rightEyeOpenProbability!;
        print('Eye openness - Left: $leftEyeOpen, Right: $rightEyeOpen');
        if (leftEyeOpen < 0.3 || rightEyeOpen < 0.3) { // Réduit de 0.4 à 0.3
          print('Eyes not open enough');
          return false;
        }
      }

      return true;
    } catch (e) {
      print('Error checking face quality: $e');
      return false;
    }
  }

  void dispose() {
    _faceDetector.close();
  }
} 