import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:lms_login_app/models/quiz_models.dart';

class ApiService {
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal();

  final String baseUrl = "https://lms.gdcollege.ca/wp-json";
  final String customNamespace = "tutor-custom/v1";

  late final Dio _dio;
  String? _token;
  Map<String, dynamic>? _userData;

  Map<String, dynamic>? get user => _userData;
  bool get isLoggedIn => _token != null;

  // Singleton initialization
  static Future<ApiService> init() async {
    final instance = ApiService();
    await instance._initialize();
    return instance;
  }

  Future<void> _initialize() async {
    // Configure Dio
    _dio = Dio(
      BaseOptions(
        baseUrl: baseUrl,
        connectTimeout: const Duration(seconds: 30),
        receiveTimeout: const Duration(seconds: 30),
        sendTimeout: const Duration(seconds: 30),
        headers: {'Content-Type': 'application/json'},
        validateStatus: (status) => status! < 500,
      ),
    );

    // Add interceptors
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          // Add token to all requests if available
          if (_token != null) {
            options.headers['Authorization'] = 'Bearer $_token';
          }
          debugPrint('🚀 ${options.method} ${options.path}');
          return handler.next(options);
        },
        onResponse: (response, handler) {
          debugPrint(
            '✅ ${response.statusCode} ${response.requestOptions.path}',
          );
          return handler.next(response);
        },
        onError: (error, handler) {
          debugPrint(
            '❌ Error: ${error.response?.statusCode} - ${error.message}',
          );
          return handler.next(error);
        },
      ),
    );

    // Load saved token
    await _loadToken();
  }

  /* =====================================================
   * TOKEN PERSISTENCE
   * ===================================================== */

  Future<void> _loadToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _token = prefs.getString('auth_token');

      final userDataString = prefs.getString('user_data');
      if (userDataString != null) {
        _userData = jsonDecode(userDataString);
      }

      if (_token != null) {
        debugPrint('🔑 Token loaded from storage');
      }
    } catch (e) {
      debugPrint('❌ Token load error: $e');
    }
  }

  Future<void> _saveToken(String token, Map<String, dynamic> userData) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('auth_token', token);
      await prefs.setString('user_data', jsonEncode(userData));
      _token = token;
      _userData = userData;
      debugPrint('💾 Token saved to storage');
    } catch (e) {
      debugPrint('❌ Token save error: $e');
    }
  }

  Future<void> _clearToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('auth_token');
      await prefs.remove('user_data');
      _token = null;
      _userData = null;
      debugPrint('🗑️ Token cleared from storage');
    } catch (e) {
      debugPrint('❌ Token clear error: $e');
    }
  }

  /* =====================================================
   * 1. AUTHENTICATION
   * ===================================================== */

  Future<bool> login(String username, String password) async {
    try {
      final response = await _dio.post(
        '/jwt-auth/v1/token',
        data: {'username': username, 'password': password},
      );

      if (response.statusCode == 200 && response.data != null) {
        final data = response.data;
        await _saveToken(data['token'], data);
        return true;
      }
      return false;
    } on DioException catch (e) {
      debugPrint("Login Error: ${e.message}");
      if (e.response?.statusCode == 403) {
        debugPrint("Invalid credentials");
      }
      return false;
    } catch (e) {
      debugPrint("Login Error: $e");
      return false;
    }
  }

  Future<void> logout() async {
    await _clearToken();
  }

  /* =====================================================
   * 2. COURSE LISTING & PROGRESS
   * ===================================================== */

  Future<List<dynamic>> getEnrolledCourses() async {
    try {
      final response = await _dio.get('/$customNamespace/enrolled-courses');

      if (response.statusCode == 200 && response.data != null) {
        return response.data['courses'] ?? [];
      }
    } on DioException catch (e) {
      debugPrint("Course List Error: ${e.message}");
    } catch (e) {
      debugPrint("Course List Error: $e");
    }
    return [];
  }

  /* =====================================================
   * 3. PASSWORD RESET
   * ===================================================== */

  Future<bool> requestPasswordReset(String email) async {
    try {
      final response = await _dio.post(
        '/gd-college/v1/reset-password',
        data: {'email': email},
        options: Options(contentType: Headers.formUrlEncodedContentType),
      );
      return response.statusCode == 200;
    } on DioException catch (e) {
      debugPrint("Password Reset Error: ${e.message}");
      return false;
    } catch (e) {
      debugPrint("Password Reset Error: $e");
      return false;
    }
  }

  /* =====================================================
   * 4. CURRICULUM & SYNC (Unified Logic)
   * ===================================================== */

  Future<List<dynamic>> getCourseCurriculum(int courseId) async {
    try {
      final response = await _dio.get(
        '/$customNamespace/course-curriculum/$courseId',
      );

      if (response.statusCode == 200 && response.data != null) {
        return response.data['topics'] ?? [];
      }
    } on DioException catch (e) {
      debugPrint("Curriculum Error: ${e.message}");
    } catch (e) {
      debugPrint("Curriculum Error: $e");
    }
    return [];
  }

  Future<Map<String, dynamic>?> getLessonDetails(int lessonId) async {
    try {
      final response = await _dio.get('/$customNamespace/lesson/$lessonId');

      if (response.statusCode == 200 && response.data != null) {
        return response.data['lesson'];
      }
    } on DioException catch (e) {
      debugPrint("Lesson Error: ${e.message}");
    } catch (e) {
      debugPrint("Lesson Error: $e");
    }
    return null;
  }

  /// Unified Sync Function for both Lessons and Quizzes
  Future<Map<String, dynamic>?> syncLessonWithWebsite(
    int itemId, {
    String itemType = 'lesson',
    int earnedMarks = 0,
  }) async {
    final payload = {
      'item_id': itemId,
      'item_type': itemType,
      'earned_marks': earnedMarks,
    };

    try {
      final response = await _dio.post(
        '/$customNamespace/sync-lesson-status',
        data: payload,
      );

      if (response.statusCode == 200 && response.data != null) {
        return response.data;
      }
    } on DioException catch (e) {
      debugPrint("API CRASH - Error: ${e.message}");
      debugPrint("Response: ${e.response?.data}");
    }
    return null;
  }

  Future<List<QuizQuestion>> getQuizQuestions(int quizId) async {
    try {
      final response = await _dio.get(
        '/$customNamespace/quiz-questions/$quizId',
      );

      if (response.statusCode == 200 && response.data != null) {
        final List questions = response.data['questions'] ?? [];
        return questions.map((q) => QuizQuestion.fromJson(q)).toList();
      }
    } on DioException catch (e) {
      debugPrint("Quiz Questions Error: ${e.message}");
    } catch (e) {
      debugPrint("Quiz Questions Error: $e");
    }
    return [];
  }

  Future<List<dynamic>> getQuizAttempts(int quizId) async {
    try {
      final response = await _dio.get(
        '/$customNamespace/quiz-attempts/$quizId',
      );

      if (response.statusCode == 200 && response.data != null) {
        return response.data['attempts'] ?? [];
      }
    } on DioException catch (e) {
      debugPrint("Quiz Attempts Error (Specific): ${e.message}");

      // IF SERVER CRASHES (500), TRY FALLBACK
      if (e.response?.statusCode == 500) {
        debugPrint(
          "⚠️ Specific endpoint failed. Attempting local filter fallback...",
        );
        return await _getQuizAttemptsFallback(quizId);
      }
    } catch (e) {
      debugPrint("Quiz Attempts Error: $e");
    }
    return [];
  }

  /// Helper to filter from the "All Attempts" endpoint if the specific one fails
  Future<List<dynamic>> _getQuizAttemptsFallback(int quizId) async {
    try {
      final allAttempts = await getAllUserQuizAttempts();
      // Filter attempts where the quiz ID matches (ensure type matching)
      final filtered = allAttempts.where((attempt) {
        final id =
            attempt['quiz_id'] ?? attempt['item_id']; // Handle varying keys
        return id.toString() == quizId.toString();
      }).toList();

      debugPrint("Fallback found ${filtered.length} attempts for Quiz $quizId");
      return filtered;
    } catch (e) {
      debugPrint("Fallback failed: $e");
      return [];
    }
  }

  /// Get all quiz attempts for the current user across all quizzes
  Future<List<Map<String, dynamic>>> getAllUserQuizAttempts() async {
    try {
      final response = await _dio.get('/$customNamespace/all-quiz-attempts');

      if (response.statusCode == 200 && response.data != null) {
        final List attempts = response.data['attempts'] ?? [];
        return attempts.map((e) => e as Map<String, dynamic>).toList();
      }
    } on DioException catch (e) {
      debugPrint("All Quiz Attempts Error: ${e.message}");
    } catch (e) {
      debugPrint("All Quiz Attempts Error: $e");
    }
    return [];
  }

  /* =====================================================
   * 5. TOKEN VALIDATION (Optional)
   * ===================================================== */

  Future<bool> validateToken() async {
    if (_token == null) return false;

    try {
      final response = await _dio.post('/jwt-auth/v1/token/validate');

      return response.statusCode == 200;
    } on DioException catch (e) {
      debugPrint("Token validation failed: ${e.message}");
      // If token is invalid, clear it
      if (e.response?.statusCode == 403) {
        await _clearToken();
      }
      return false;
    } catch (e) {
      debugPrint("Token validation error: $e");
      return false;
    }
  }
  /* =====================================================
 * 6. USER PROFILE
 * ===================================================== */

  Future<Map<String, dynamic>?> getUserProfile() async {
    try {
      final response = await _dio.get('/$customNamespace/profile');

      if (response.statusCode == 200 && response.data != null) {
        return response.data;
      }
    } on DioException catch (e) {
      debugPrint("Profile Error: ${e.message}");
    } catch (e) {
      debugPrint("Profile Error: $e");
    }
    return null;
  }

  Future<bool> updateUserProfile(Map<String, dynamic> profileData) async {
    try {
      debugPrint("📤 Updating profile with data: $profileData");

      final response = await _dio.post(
        '/$customNamespace/profile/update',
        data: profileData,
      );

      debugPrint("Profile update response: ${response.data}");

      return response.statusCode == 200;
    } on DioException catch (e) {
      debugPrint("Profile Update Error: ${e.message}");
      debugPrint("Response data: ${e.response?.data}");
      return false;
    } catch (e) {
      debugPrint("Profile Update Error: $e");
      return false;
    }
  }

  Future<Map<String, dynamic>> resetPassword(
    String currentPassword,
    String newPassword,
  ) async {
    try {
      final response = await _dio.post(
        '/$customNamespace/reset-password',
        data: {
          'current_password': currentPassword,
          'new_password': newPassword,
        },
      );

      if (response.statusCode == 200 && response.data != null) {
        return response.data;
      }
      return {'success': false, 'message': 'Failed to reset password'};
    } on DioException catch (e) {
      debugPrint("Reset Password Error: ${e.message}");
      return {
        'success': false,
        'message': e.response?.data['message'] ?? 'An error occurred',
      };
    } catch (e) {
      debugPrint("Reset Password Error: $e");
      return {'success': false, 'message': 'An error occurred'};
    }
  }

  // In api_service.dart, add this method temporarily
  Future<void> debugUserMeta() async {
    try {
      final response = await _dio.get('/$customNamespace/profile/debug');
      debugPrint("🔍 ALL USER META:");
      debugPrint(response.data.toString());
    } catch (e) {
      debugPrint("Debug error: $e");
    }
  }

  /* =====================================================
   * 7. PROFILE PHOTO UPLOAD
   * ===================================================== */

  Future<Map<String, dynamic>?> uploadProfilePhoto(File imageFile) async {
    try {
      debugPrint("📸 Uploading profile photo...");

      // Create form data
      String fileName = imageFile.path.split('/').last;
      FormData formData = FormData.fromMap({
        'profile_photo': await MultipartFile.fromFile(
          imageFile.path,
          filename: fileName,
        ),
      });

      final response = await _dio.post(
        '/$customNamespace/profile/upload-photo',
        data: formData,
        options: Options(headers: {'Content-Type': 'multipart/form-data'}),
      );

      debugPrint("📥 Upload response: ${response.data}");

      if (response.statusCode == 200 && response.data != null) {
        return response.data;
      }
      return {'success': false, 'message': 'Upload failed'};
    } on DioException catch (e) {
      debugPrint("Profile Photo Upload Error: ${e.message}");
      debugPrint("Response: ${e.response?.data}");
      return {
        'success': false,
        'message': e.response?.data['message'] ?? 'Upload failed',
      };
    } catch (e) {
      debugPrint("Profile Photo Upload Error: $e");
      return {'success': false, 'message': 'Upload failed: $e'};
    }
  }

  /* =====================================================
   * 8. COURSE REVIEWS & RATINGS
   * ===================================================== */

  Future<Map<String, dynamic>?> getCourseRatings(int courseId) async {
    try {
      final response = await _dio.get(
        '/$customNamespace/course-ratings/$courseId',
      );

      if (response.statusCode == 200 && response.data != null) {
        return response.data;
      }
    } on DioException catch (e) {
      debugPrint("Course Ratings Error: ${e.message}");
    } catch (e) {
      debugPrint("Course Ratings Error: $e");
    }
    return null;
  }

  Future<bool> submitReview(int courseId, double rating, String comment) async {
    try {
      final response = await _dio.post(
        '/$customNamespace/submit-review',
        data: {'course_id': courseId, 'rating': rating, 'comment': comment},
      );

      return response.statusCode == 200 &&
          response.data != null &&
          response.data['success'] == true;
    } on DioException catch (e) {
      debugPrint("Submit Review Error: ${e.message}");
      return false;
    } catch (e) {
      debugPrint("Submit Review Error: $e");
      return false;
    }
  }
}

// Global instance
final apiService = ApiService();
