import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/material.dart';
import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:universal_html/html.dart' if (dart.library.html) 'dart:html' as html;

class AuthProvider with ChangeNotifier {
  final SupabaseClient _supabase = Supabase.instance.client;

  User? get currentUser => _supabase.auth.currentUser;
  Stream<AuthState> get authStateChanges => _supabase.auth.onAuthStateChange;

  Future<String> _getBase64Image(dynamic imageFile) async {
    if (kIsWeb) {
      // Pour le web
      final reader = html.FileReader();
      reader.readAsDataUrl(imageFile);
      await reader.onLoad.first;
      final String base64 = reader.result as String;
      return base64.split(',')[1]; // Enlever le préfixe data:image/jpeg;base64,
    } else {
      // Pour les plateformes natives
      final bytes = await (imageFile as File).readAsBytes();
      return base64Encode(bytes);
    }
  }

  Future<void> signUp({
    required String email,
    required String password,
    required dynamic imageFile,
  }) async {
    try {
      print('Début de l\'inscription pour: $email');
      
      // Convert image to base64
      final base64Image = await _getBase64Image(imageFile);
      print('Image convertie en base64');

      // Create user with email and password
      final response = await _supabase.auth.signUp(
        email: email,
        password: password,
      );
      print('Utilisateur créé avec l\'ID: ${response.user?.id}');

      if (response.user != null) {
        try {
          print('Tentative d\'insertion dans la table users');
          // Save user data to Supabase
          final result = await _supabase.from('users').insert({
            'id': response.user!.id,
            'email': email,
            'face_image': base64Image,
            'created_at': DateTime.now().toIso8601String(),
            'updated_at': DateTime.now().toIso8601String(),
          }).select();
          print('Données utilisateur insérées avec succès: $result');
        } catch (e) {
          print('Erreur lors de l\'insertion: $e');
          // Si l'insertion échoue, supprimer l'utilisateur créé
          try {
            await _supabase.auth.admin.deleteUser(response.user!.id);
            print('Utilisateur supprimé après erreur d\'insertion');
          } catch (deleteError) {
            print('Erreur lors de la suppression de l\'utilisateur: $deleteError');
          }

          if (e.toString().contains('violates unique constraint')) {
            throw 'Un compte avec cet email existe déjà';
          } else if (e.toString().contains('violates foreign key constraint')) {
            throw 'Erreur lors de la création du compte. Veuillez réessayer.';
          } else if (e.toString().contains('violates row-level security policy')) {
            throw 'Erreur de sécurité. Veuillez contacter l\'administrateur.';
          } else {
            throw 'Erreur lors de la création du compte: ${e.toString()}';
          }
        }
      }

      notifyListeners();
      print('Inscription terminée avec succès');
    } catch (e) {
      print('Erreur finale: $e');
      rethrow;
    }
  }

  Future<void> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    try {
      await _supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );
      notifyListeners();
    } catch (e) {
      rethrow;
    }
  }

  Future<void> signOut() async {
    await _supabase.auth.signOut();
    notifyListeners();
  }

  Future<String?> getUserImageBase64() async {
    if (currentUser == null) return null;
    
    final response = await _supabase
        .from('users')
        .select('face_image')
        .eq('id', currentUser!.id)
        .single();
    return response['face_image'];
  }

  Future<void> updateUserImage(dynamic imageFile) async {
    if (currentUser == null) return;

    try {
      final base64Image = await _getBase64Image(imageFile);

      await _supabase.from('users').update({
        'face_image': base64Image,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', currentUser!.id);

      notifyListeners();
    } catch (e) {
      rethrow;
    }
  }
} 