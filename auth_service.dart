import 'package:supabase_flutter/supabase_flutter.dart';

class AuthService {
  final SupabaseClient _supabase = Supabase.instance.client;

  // Get current user
  User? getCurrentUser() {
    return _supabase.auth.currentUser;
  }

  // Get user data from Supabase
  Future<Map<String, dynamic>?> getUserData(String uid) async {
    try {
      final response = await _supabase
          .from('users')
          .select()
          .eq('id', uid)
          .single();
      return response;
    } catch (e) {
      print('Error getting user data: $e');
      return null;
    }
  }

  // Sign in with email and password
  Future<AuthResponse?> signIn(String email, String password) async {
    try {
      return await _supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );
    } catch (e) {
      print('Error signing in: $e');
      return null;
    }
  }

  // Sign up with email, password and face image
  Future<AuthResponse?> signUp(String email, String password, String faceImageBase64) async {
    try {
      final response = await _supabase.auth.signUp(
        email: email,
        password: password,
      );

      if (response.user != null) {
        // Save user data to Supabase
        await _supabase.from('users').insert({
          'id': response.user!.id,
          'email': email,
          'face_image': faceImageBase64,
          'created_at': DateTime.now().toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
        });
      }

      return response;
    } catch (e) {
      print('Error signing up: $e');
      return null;
    }
  }

  // Sign out
  Future<void> signOut() async {
    try {
      await _supabase.auth.signOut();
    } catch (e) {
      print('Error signing out: $e');
    }
  }

  // Update face image
  Future<bool> updateFaceImage(String uid, String faceImageBase64) async {
    try {
      await _supabase.from('users').update({
        'face_image': faceImageBase64,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', uid);
      return true;
    } catch (e) {
      print('Error updating face image: $e');
      return false;
    }
  }
} 