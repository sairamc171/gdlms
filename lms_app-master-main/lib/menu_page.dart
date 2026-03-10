import 'package:flutter/material.dart';
import 'app_theme.dart';
import 'services/api_service.dart';
import 'models/user_profile.dart';
import 'enrolled_courses_page.dart';
import 'profile_page.dart';
import 'main.dart';
import 'settings_page.dart';
import 'dashboard_page.dart';
import 'quiz_attempts_page.dart';

class MenuPage extends StatefulWidget {
  const MenuPage({super.key});

  @override
  State<MenuPage> createState() => _MenuPageState();
}

class _MenuPageState extends State<MenuPage> {
  UserProfile? _profile;
  bool _isLoadingProfile = true;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final data = await apiService.getUserProfile();
    if (data != null && mounted) {
      setState(() {
        _profile = UserProfile.fromJson(data);
        _isLoadingProfile = false;
      });
    } else if (mounted) {
      setState(() => _isLoadingProfile = false);
    }
  }

  String get _displayName {
    if (_profile == null) return '';
    final full = '${_profile!.user.firstName} ${_profile!.user.lastName}'
        .trim();
    if (full.isNotEmpty) return full;
    return _profile!.user.username;
  }

  String get _displayEmail => _profile?.user.email ?? '';

  String? get _avatarUrl {
    final url = _profile?.user.profilePhoto;
    return (url != null && url.isNotEmpty) ? url : null;
  }

  String get _initial {
    if (_profile == null) return '';
    if (_profile!.user.firstName.isNotEmpty) {
      return _profile!.user.firstName[0].toUpperCase();
    }
    if (_profile!.user.username.isNotEmpty) {
      return _profile!.user.username[0].toUpperCase();
    }
    return 'U';
  }

  Future<void> _handleLogout(BuildContext context) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Logout', style: AppTheme.cardTitle),
        content: Text(
          'Are you sure you want to logout?',
          style: AppTheme.bodySmall,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Logout', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true && context.mounted) {
      await apiService.logout();
      if (context.mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const LoginPage()),
          (route) => false,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppTheme.background,
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        children: [
          // ── Profile Card ──────────────────────────────────────
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: AppTheme.cardDecoration,
            child: Row(
              children: [
                _buildAvatar(),
                const SizedBox(width: 14),
                Expanded(
                  child: _isLoadingProfile
                      ? _buildProfileSkeleton()
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _displayName.isNotEmpty ? _displayName : '—',
                              style: AppTheme.cardTitle,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _displayEmail.isNotEmpty ? _displayEmail : '—',
                              style: AppTheme.labelSmall,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // ── Main menu card ────────────────────────────────────
          _buildMenuCard([
            _buildMenuTile(
              context,
              icon: Icons.speed_outlined,
              title: 'Dashboard',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const DashboardPage()),
              ),
              showDivider: true,
            ),
            _buildMenuTile(
              context,
              icon: Icons.person_outline,
              title: 'My Profile',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ProfilePage()),
              ).then((_) => _loadProfile()),
              showDivider: true,
            ),
            _buildMenuTile(
              context,
              icon: Icons.school_outlined,
              title: 'Enrolled Courses',
              // FIX: use pushReplacement (not pushAndRemoveUntil) so the bottom
              // nav root is preserved, but the Menu/Dashboard back stack is
              // cleared. The double back-button issue is fully resolved by the
              // automaticallyImplyLeading fix in AppTheme.buildAppBar.
              onTap: () => Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => const EnrolledCoursesPage()),
              ),
              showDivider: true,
            ),
            _buildMenuTile(
              context,
              icon: Icons.quiz_outlined,
              title: 'Quiz Attempts',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const QuizAttemptsPage()),
              ),
              showDivider: false,
            ),
          ]),

          const SizedBox(height: 16),

          // ── Settings card ─────────────────────────────────────
          _buildMenuCard([
            _buildMenuTile(
              context,
              icon: Icons.settings_outlined,
              title: 'Settings',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SettingsPage()),
              ),
              showDivider: false,
            ),
          ]),

          const SizedBox(height: 16),

          // ── Logout button ─────────────────────────────────────
          OutlinedButton.icon(
            onPressed: () => _handleLogout(context),
            icon: const Icon(Icons.logout_rounded, color: AppTheme.primary),
            label: Text(
              'Logout',
              style: AppTheme.bodyMedium.copyWith(
                color: AppTheme.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: AppTheme.primary, width: 1.5),
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              backgroundColor: AppTheme.surface,
            ),
          ),

          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildAvatar() {
    final url = _avatarUrl;
    final bool hasPhoto = url != null && url.isNotEmpty;

    if (_isLoadingProfile && _profile == null) {
      return Container(
        width: 60,
        height: 60,
        decoration: const BoxDecoration(
          color: AppTheme.placeholder,
          shape: BoxShape.circle,
        ),
      );
    }

    if (hasPhoto) {
      return ClipOval(
        child: Image.network(
          url,
          width: 60,
          height: 60,
          fit: BoxFit.cover,
          headers: const {
            'Cache-Control': 'no-cache, no-store, must-revalidate',
            'Pragma': 'no-cache',
          },
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return Container(
              width: 60,
              height: 60,
              color: AppTheme.placeholder,
              child: const Center(
                child: CircularProgressIndicator(
                  color: AppTheme.primary,
                  strokeWidth: 2,
                ),
              ),
            );
          },
          errorBuilder: (context, error, stackTrace) =>
              _initialsAvatar(_initial, 30),
        ),
      );
    }

    return _initialsAvatar(_initial, 30);
  }

  Widget _initialsAvatar(String initial, double radius) {
    return CircleAvatar(
      radius: radius,
      backgroundColor: AppTheme.primary,
      child: Text(
        initial,
        style: AppTheme.bodyMedium.copyWith(
          fontSize: radius * 0.8,
          fontWeight: FontWeight.bold,
          color: AppTheme.surface,
        ),
      ),
    );
  }

  Widget _buildProfileSkeleton() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          height: 14,
          width: 120,
          decoration: const BoxDecoration(
            color: AppTheme.placeholder,
            borderRadius: BorderRadius.all(Radius.circular(4)),
          ),
        ),
        const SizedBox(height: 6),
        Container(
          height: 11,
          width: 180,
          decoration: const BoxDecoration(
            color: AppTheme.placeholder,
            borderRadius: BorderRadius.all(Radius.circular(4)),
          ),
        ),
      ],
    );
  }

  Widget _buildMenuCard(List<Widget> children) {
    return Container(
      decoration: AppTheme.cardDecoration,
      child: Column(children: children),
    );
  }

  Widget _buildMenuTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    VoidCallback? onTap,
    bool showDivider = true,
  }) {
    return Column(
      children: [
        ListTile(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 4,
          ),
          leading: Icon(icon, color: AppTheme.primary, size: 24),
          title: Text(title, style: AppTheme.bodyMedium),
          trailing: const Icon(
            Icons.chevron_right,
            color: AppTheme.textHint,
            size: 22,
          ),
          onTap: onTap,
        ),
        if (showDivider)
          const Divider(
            height: 1,
            thickness: 1,
            color: AppTheme.divider,
            indent: 20,
            endIndent: 20,
          ),
      ],
    );
  }
}
