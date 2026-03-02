import 'package:flutter/material.dart';
import 'app_theme.dart';
import 'services/api_service.dart';
import 'models/user_profile.dart';
import 'main.dart';
import 'package:intl/intl.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  UserProfile? _profile;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    setState(() => _isLoading = true);
    imageCache.clear();
    imageCache.clearLiveImages();
    final data = await apiService.getUserProfile();
    if (data != null && mounted) {
      setState(() {
        _profile = UserProfile.fromJson(data);
        _isLoading = false;
      });
    } else {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _handleLogout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Logout', style: AppTheme.cardTitle),
        content: Text(
          'Are you sure you want to logout?',
          style: AppTheme.bodySmall,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Cancel',
              style: AppTheme.labelMedium.copyWith(
                color: AppTheme.textSecondary,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('Logout'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await apiService.logout();
      // FIX: guard context use with mounted check after async gap
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const LoginPage()),
          (route) => false,
        );
      }
    }
  }

  String _formatDate(String dateString) {
    try {
      final date = DateTime.parse(dateString);
      return DateFormat('MMMM dd, yyyy  h:mm a').format(date);
    } catch (e) {
      return dateString;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: AppTheme.background,
        body: Center(child: CircularProgressIndicator(color: AppTheme.primary)),
      );
    }

    if (_profile == null) {
      return Scaffold(
        backgroundColor: AppTheme.background,
        appBar: AppTheme.buildAppBar(title: 'My Profile'),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 56, color: Colors.grey[300]),
              const SizedBox(height: 16),
              Text(
                'Failed to load profile',
                style: AppTheme.bodyMedium.copyWith(color: Colors.grey[400]),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _loadProfile,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  foregroundColor: AppTheme.surface,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: Text(
                  'Retry',
                  style: AppTheme.labelMedium.copyWith(color: AppTheme.surface),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppTheme.buildAppBar(
        title: 'My Profile',
        actions: [
          IconButton(
            icon: const Icon(Icons.logout_rounded, color: Colors.red, size: 22),
            onPressed: _handleLogout,
            tooltip: 'Logout',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadProfile,
        color: AppTheme.primary,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            children: [
              // ── Profile hero ──────────────────────────────────
              Container(
                width: double.infinity,
                color: AppTheme.surface,
                padding: const EdgeInsets.fromLTRB(24, 32, 24, 32),
                child: Column(
                  children: [
                    _buildAvatar(),
                    const SizedBox(height: 16),
                    Text(
                      '${_profile!.user.firstName} ${_profile!.user.lastName}'
                          .trim(),
                      style: AppTheme.headingMedium,
                      textAlign: TextAlign.center,
                    ),
                    if (_profile!.user.jobTitle.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        _profile!.user.jobTitle,
                        style: AppTheme.labelMedium,
                      ),
                    ],
                  ],
                ),
              ),

              Container(height: 1, color: AppTheme.divider),

              // ── Info list ─────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
                child: Container(
                  decoration: AppTheme.cardDecoration,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: Column(
                      children: [
                        _buildInfoRow(
                          'Registration Date',
                          _formatDate(_profile!.user.registeredDate),
                          Icons.calendar_today_outlined,
                        ),
                        AppTheme.cardDivider,
                        _buildInfoRow(
                          'First Name',
                          _profile!.user.firstName,
                          Icons.person_outline,
                        ),
                        AppTheme.cardDivider,
                        _buildInfoRow(
                          'Last Name',
                          _profile!.user.lastName,
                          Icons.person_outline,
                        ),
                        AppTheme.cardDivider,
                        _buildInfoRow(
                          'Username',
                          _profile!.user.username,
                          Icons.account_circle_outlined,
                        ),
                        AppTheme.cardDivider,
                        _buildInfoRow(
                          'Email',
                          _profile!.user.email,
                          Icons.email_outlined,
                        ),
                        AppTheme.cardDivider,
                        _buildInfoRow(
                          'Phone',
                          _profile!.user.phone.isEmpty
                              ? '—'
                              : _profile!.user.phone,
                          Icons.phone_outlined,
                        ),
                        AppTheme.cardDivider,
                        _buildInfoRow(
                          'Occupation',
                          _profile!.user.jobTitle.isEmpty
                              ? 'Student'
                              : _profile!.user.jobTitle,
                          Icons.work_outline,
                        ),
                        AppTheme.cardDivider,
                        _buildInfoRow(
                          'Biography',
                          _profile!.user.bio.isEmpty ? '—' : _profile!.user.bio,
                          Icons.info_outline,
                          isMultiline: true,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAvatar() {
    final String photoUrl = _profile!.user.profilePhoto;
    final bool hasPhoto = photoUrl.isNotEmpty;
    final String photoUrlWithBust = hasPhoto
        ? '$photoUrl?nocache=${DateTime.now().millisecondsSinceEpoch}'
        : '';
    final String initial = _profile!.user.firstName.isNotEmpty
        ? _profile!.user.firstName[0].toUpperCase()
        : _profile!.user.username.isNotEmpty
        ? _profile!.user.username[0].toUpperCase()
        : 'U';

    if (hasPhoto) {
      return ClipOval(
        child: Image.network(
          photoUrlWithBust,
          width: 100,
          height: 100,
          fit: BoxFit.cover,
          headers: const {
            'Cache-Control': 'no-cache, no-store, must-revalidate',
            'Pragma': 'no-cache',
          },
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return Container(
              width: 100,
              height: 100,
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
              _initialsAvatar(initial, 50),
        ),
      );
    }
    return _initialsAvatar(initial, 50);
  }

  Widget _initialsAvatar(String initial, double radius) {
    return CircleAvatar(
      radius: radius,
      backgroundColor: AppTheme.primary,
      child: Text(
        initial,
        style: AppTheme.headingLarge.copyWith(
          fontSize: radius * 0.7,
          color: AppTheme.surface,
        ),
      ),
    );
  }

  Widget _buildInfoRow(
    String label,
    String value,
    IconData icon, {
    bool isMultiline = false,
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
      child: Row(
        crossAxisAlignment: isMultiline
            ? CrossAxisAlignment.start
            : CrossAxisAlignment.center,
        children: [
          Icon(icon, size: 18, color: AppTheme.primary.withValues(alpha: 0.6)),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: AppTheme.labelSmall),
                const SizedBox(height: 3),
                Text(
                  value,
                  style: AppTheme.bodyMedium.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: isMultiline ? null : 1,
                  overflow: isMultiline ? null : TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
