import 'package:flutter/material.dart';
import 'package:app_links/app_links.dart';
import 'dart:async';
import 'dashboard_page.dart';
import 'services/api_service.dart';
import 'forgot_password_page.dart';
import 'reset_password_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await ApiService.init();
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final _navigatorKey = GlobalKey<NavigatorState>();
  late final AppLinks _appLinks;
  StreamSubscription? _linkSubscription;

  ResetPasswordPage? _pendingPage;

  @override
  void initState() {
    super.initState();
    _initDeepLinks();
  }

  @override
  void dispose() {
    _linkSubscription?.cancel();
    super.dispose();
  }

  Future<void> _initDeepLinks() async {
    _appLinks = AppLinks();

    try {
      final initialUri = await _appLinks.getInitialLink();
      if (initialUri != null) {
        debugPrint('🔗 Cold-start deep link: $initialUri');
        _pendingPage = _parseDeepLink(initialUri);
      }
    } catch (e) {
      debugPrint('Deep link initial error: $e');
    }

    _linkSubscription = _appLinks.uriLinkStream.listen((uri) {
      debugPrint('🔗 Hot deep link: $uri');
      final page = _parseDeepLink(uri);
      if (page != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _navigatorKey.currentState?.push(
            MaterialPageRoute(builder: (_) => page),
          );
        });
      }
    }, onError: (e) => debugPrint('Deep link stream error: $e'));
  }

  ResetPasswordPage? _parseDeepLink(Uri uri) {
    final fixedUri = Uri.parse(uri.toString().replaceAll('&amp;', '&'));

    debugPrint('🔍 URI received: $fixedUri');
    debugPrint('🔍 URI host: ${fixedUri.host}');
    debugPrint('🔍 URI path: ${fixedUri.path}');
    debugPrint('🔍 URI query params: ${fixedUri.queryParameters}');

    final bool isHttpsLink = fixedUri.path.contains('app-redirect');
    final bool isCustomScheme = fixedUri.host == 'reset-password';

    if (isHttpsLink || isCustomScheme) {
      final userIdStr = fixedUri.queryParameters['user'];
      final resetKey = fixedUri.queryParameters['key'];

      debugPrint('🔍 userIdStr: $userIdStr, resetKey: $resetKey');

      if (userIdStr != null && resetKey != null && resetKey.isNotEmpty) {
        final userId = int.tryParse(userIdStr);
        if (userId != null) {
          debugPrint('✅ Parsed reset link — userId: $userId');
          return ResetPasswordPage(userId: userId, resetKey: resetKey);
        }
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: _navigatorKey,
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: const Color(0xFF6D391E),
      ),
      home: _buildHome(),
    );
  }

  Widget _buildHome() {
    if (_pendingPage != null) {
      final page = _pendingPage!;
      _pendingPage = null;

      WidgetsBinding.instance.addPostFrameCallback((_) {
        _navigatorKey.currentState?.push(
          MaterialPageRoute(builder: (_) => page),
        );
      });
    }

    return apiService.isLoggedIn ? const DashboardPage() : const LoginPage();
  }
}

// ---------------------------------------------------------------------------
// Login Page — pixel-matched to the provided design screenshot
// ---------------------------------------------------------------------------

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _userController = TextEditingController();
  final _passController = TextEditingController();
  bool _isLoading = false;
  bool _keepSignedIn = false;
  bool _obscurePassword = true;

  // Colors extracted from the screenshot
  static const Color _brown = Color(0xFF6D391E);
  static const Color _bgBeige = Color(0xFFEDE8DF);

  @override
  void dispose() {
    _userController.dispose();
    _passController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgBeige,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Logo centered at top ──
              const SizedBox(height: 48),
              Center(child: Image.asset('assets/GD-logo.png', height: 75)),

              // ── Large left-aligned welcome text ──
              const SizedBox(height: 52),
              const Text(
                'Hi,\nWelcome back!',
                style: TextStyle(
                  fontSize: 38,
                  fontWeight: FontWeight.w800,
                  color: _brown,
                  height: 1.15,
                ),
              ),

              // ── Email / Username field ──
              const SizedBox(height: 36),
              _buildPillField(
                controller: _userController,
                hint: 'Email / Username',
                prefixIcon: Icons.email_outlined,
              ),

              // ── Password field ──
              const SizedBox(height: 16),
              _buildPillField(
                controller: _passController,
                hint: 'Password',
                prefixIcon: Icons.lock_outline,
                obscure: _obscurePassword,
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscurePassword
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                    color: Colors.grey.shade500,
                    size: 22,
                  ),
                  onPressed: () =>
                      setState(() => _obscurePassword = !_obscurePassword),
                ),
                onSubmitted: (_) => _handleLogin(),
              ),

              // ── Keep signed in + Forgot Password ──
              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      SizedBox(
                        width: 22,
                        height: 22,
                        child: Checkbox(
                          value: _keepSignedIn,
                          onChanged: (v) =>
                              setState(() => _keepSignedIn = v ?? false),
                          activeColor: _brown,
                          side: BorderSide(
                            color: Colors.grey.shade500,
                            width: 1.5,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'Keep me signed in',
                        style: TextStyle(
                          fontSize: 13,
                          color: _brown,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  GestureDetector(
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const ForgotPasswordPage(),
                      ),
                    ),
                    child: const Text(
                      'Forgot Password?',
                      style: TextStyle(
                        fontSize: 13,
                        color: _brown,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),

              // ── Sign In button with shadow ──
              const SizedBox(height: 36),
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(50),
                  boxShadow: [
                    BoxShadow(
                      color: _brown.withOpacity(0.35),
                      blurRadius: 18,
                      offset: const Offset(0, 7),
                    ),
                  ],
                ),
                child: SizedBox(
                  width: double.infinity,
                  height: 58,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _brown,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(50),
                      ),
                    ),
                    onPressed: _isLoading ? null : _handleLogin,
                    child: _isLoading
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2.5,
                            ),
                          )
                        : const Text(
                            'Sign In',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.3,
                            ),
                          ),
                  ),
                ),
              ),

              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  /// White pill-shaped input field with prefix icon
  Widget _buildPillField({
    required TextEditingController controller,
    required String hint,
    required IconData prefixIcon,
    bool obscure = false,
    Widget? suffixIcon,
    ValueChanged<String>? onSubmitted,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(50),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextField(
        controller: controller,
        obscureText: obscure,
        onSubmitted: onSubmitted,
        style: const TextStyle(fontSize: 15, color: Colors.black87),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 15),
          prefixIcon: Icon(prefixIcon, color: Colors.grey.shade500, size: 22),
          suffixIcon: suffixIcon,
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            vertical: 18,
            horizontal: 20,
          ),
        ),
      ),
    );
  }

  Future<void> _handleLogin() async {
    if (_userController.text.trim().isEmpty ||
        _passController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter username and password')),
      );
      return;
    }

    setState(() => _isLoading = true);

    bool success = await apiService.login(
      _userController.text.trim(),
      _passController.text.trim(),
    );

    if (mounted) {
      if (success) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const DashboardPage()),
        );
      } else {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Invalid Credentials'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
