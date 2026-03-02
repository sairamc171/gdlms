import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'app_theme.dart';
import 'services/api_service.dart';
import 'models/user_profile.dart';
import 'package:flutter/services.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  UserProfile? _profile;
  bool _isLoadingProfile = true;
  bool _isUploadingPhoto = false;
  int _photoCacheBust = 0;
  final ImagePicker _picker = ImagePicker();

  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _isResetting = false;

  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _jobTitleController = TextEditingController();
  final _bioController = TextEditingController();
  bool _isUpdatingProfile = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadProfile();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    _firstNameController.dispose();
    _lastNameController.dispose();
    _phoneController.dispose();
    _jobTitleController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    setState(() => _isLoadingProfile = true);
    final data = await apiService.getUserProfile();
    if (data != null && mounted) {
      setState(() {
        _profile = UserProfile.fromJson(data);
        _firstNameController.text = _profile!.user.firstName;
        _lastNameController.text = _profile!.user.lastName;
        _phoneController.text = _profile!.user.phone;
        _jobTitleController.text = _profile!.user.jobTitle;
        _bioController.text = _profile!.user.bio;
        _isLoadingProfile = false;
      });
    } else {
      setState(() => _isLoadingProfile = false);
    }
  }

  Future<void> _handlePhotoUpload() async {
    try {
      final bool isAvailable = await _picker.supportsImageSource(
        ImageSource.gallery,
      );
      if (!isAvailable) {
        _showError('Image picker not available on this device');
        return;
      }

      final ImageSource? source = await showDialog<ImageSource>(
        context: context,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Text('Choose Photo Source', style: AppTheme.cardTitle),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: Icon(
                  Icons.camera_alt_outlined,
                  color: AppTheme.primary,
                ),
                title: Text('Camera', style: AppTheme.bodyMedium),
                onTap: () => Navigator.pop(context, ImageSource.camera),
              ),
              ListTile(
                leading: Icon(
                  Icons.photo_library_outlined,
                  color: AppTheme.primary,
                ),
                title: Text('Gallery', style: AppTheme.bodyMedium),
                onTap: () => Navigator.pop(context, ImageSource.gallery),
              ),
            ],
          ),
        ),
      );
      if (source == null) return;

      final XFile? image = await _picker
          .pickImage(
            source: source,
            maxWidth: 800,
            maxHeight: 800,
            imageQuality: 85,
          )
          .catchError((error) {
            _showError('Failed to pick image: $error');
            return null;
          });
      if (image == null) {
        _showError('No image selected');
        return;
      }

      setState(() => _isUploadingPhoto = true);
      final result = await apiService.uploadProfilePhoto(File(image.path));
      if (!mounted) return;

      if (result != null && result['success'] == true) {
        setState(() {
          _photoCacheBust = DateTime.now().millisecondsSinceEpoch;
          _isUploadingPhoto = false;
        });
        _showSuccess('Profile photo updated!');
        await _loadProfile();
      } else {
        setState(() => _isUploadingPhoto = false);
        _showError(result?['message'] ?? 'Failed to upload photo');
      }
    } on PlatformException catch (e) {
      if (!mounted) return;
      setState(() => _isUploadingPhoto = false);
      _showError('Platform error: ${e.message}');
    } catch (e) {
      if (!mounted) return;
      setState(() => _isUploadingPhoto = false);
      _showError('Error: $e');
    }
  }

  Future<void> _handlePasswordReset() async {
    final String currentPass = _currentPasswordController.text;
    final String newPass = _newPasswordController.text;
    final String confirmPass = _confirmPasswordController.text;
    if (currentPass.isEmpty || newPass.isEmpty || confirmPass.isEmpty) {
      _showError("Please fill in all password fields");
      return;
    }
    if (newPass.length < 8) {
      _showError("Password must be at least 8 characters");
      return;
    }
    if (!RegExp(r'[0-9]').hasMatch(newPass) ||
        !RegExp(r'[!@#$%^&*(),.?":{}|<>]').hasMatch(newPass)) {
      _showError("Password must include a number and a special character");
      return;
    }
    if (currentPass == newPass) {
      _showError("New password cannot match current password");
      return;
    }
    if (newPass != confirmPass) {
      _showError("Passwords do not match");
      return;
    }

    setState(() => _isResetting = true);
    try {
      final result = await apiService.resetPassword(currentPass, newPass);
      if (!mounted) return;
      setState(() => _isResetting = false);
      if (result['success']) {
        _showSuccess(result['message']);
        _currentPasswordController.clear();
        _newPasswordController.clear();
        _confirmPasswordController.clear();
      } else {
        _showError(result['message'] ?? "Failed to reset password");
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isResetting = false);
      _showError("An error occurred: $e");
    }
  }

  Future<void> _handleProfileUpdate() async {
    if (_firstNameController.text.isEmpty || _lastNameController.text.isEmpty) {
      _showError("First name and last name are required");
      return;
    }
    setState(() => _isUpdatingProfile = true);
    try {
      final success = await apiService.updateUserProfile({
        'first_name': _firstNameController.text,
        'last_name': _lastNameController.text,
        'phone': _phoneController.text,
        'job_title': _jobTitleController.text,
        'bio': _bioController.text,
      });
      if (!mounted) return;
      setState(() => _isUpdatingProfile = false);
      if (success) {
        _showSuccess("Profile updated!");
        await _loadProfile();
      } else {
        _showError("Failed to update profile");
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isUpdatingProfile = false);
      _showError("An error occurred: $e");
    }
  }

  void _showError(String msg) => ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(
        msg,
        style: AppTheme.labelMedium.copyWith(color: Colors.white),
      ),
      backgroundColor: Colors.red,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ),
  );

  void _showSuccess(String msg) => ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(
        msg,
        style: AppTheme.labelMedium.copyWith(color: Colors.white),
      ),
      backgroundColor: AppTheme.completed,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ),
  );

  String _buildPhotoUrl(String baseUrl) {
    final bust = _photoCacheBust > 0
        ? _photoCacheBust
        : DateTime.now().millisecondsSinceEpoch;
    return '$baseUrl?v=$bust';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppTheme.buildAppBar(title: "Settings"),
      body: _isLoadingProfile
          ? const Center(
              child: CircularProgressIndicator(color: AppTheme.primary),
            )
          : Column(
              children: [
                // Tab bar
                Container(
                  color: AppTheme.surface,
                  child: TabBar(
                    controller: _tabController,
                    indicatorColor: AppTheme.primary,
                    indicatorWeight: 2,
                    labelColor: AppTheme.primary,
                    unselectedLabelColor: AppTheme.textSecondary,
                    labelStyle: AppTheme.labelMedium.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                    unselectedLabelStyle: AppTheme.labelMedium,
                    tabs: const [
                      Tab(text: "Profile"),
                      Tab(text: "Password"),
                    ],
                  ),
                ),
                Container(height: 1, color: AppTheme.divider),
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [_buildProfileTab(), _buildPasswordTab()],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildPasswordTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildInputField(
            "Current Password",
            "Enter current password",
            isPassword: true,
            controller: _currentPasswordController,
          ),
          _buildInputField(
            "New Password",
            "Enter new password",
            isPassword: true,
            controller: _newPasswordController,
          ),
          _buildInputField(
            "Confirm New Password",
            "Re-enter new password",
            isPassword: true,
            controller: _confirmPasswordController,
          ),
          const SizedBox(height: 28),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: _isResetting ? null : _handlePasswordReset,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: _isResetting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : Text(
                      "Reset Password",
                      style: AppTheme.bodyMedium.copyWith(
                        color: AppTheme.surface,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileTab() {
    if (_profile == null)
      return Center(
        child: Text(
          'Failed to load profile',
          style: AppTheme.bodyMedium.copyWith(color: Colors.grey[400]),
        ),
      );

    final String photoUrl = _profile!.user.profilePhoto;
    final bool hasPhoto = photoUrl.isNotEmpty;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 28, 20, 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Avatar
          Center(
            child: Stack(
              children: [
                CircleAvatar(
                  radius: 56,
                  backgroundColor: hasPhoto
                      ? AppTheme.placeholder
                      : AppTheme.primary,
                  backgroundImage: hasPhoto
                      ? NetworkImage(_buildPhotoUrl(photoUrl))
                      : null,
                  onBackgroundImageError: hasPhoto
                      ? (_, __) {
                          if (mounted) setState(() {});
                        }
                      : null,
                  child: !hasPhoto
                      ? Text(
                          _profile!.user.firstName.isNotEmpty
                              ? _profile!.user.firstName[0].toUpperCase()
                              : 'U',
                          style: AppTheme.headingLarge.copyWith(
                            color: AppTheme.surface,
                          ),
                        )
                      : null,
                ),
                if (_isUploadingPhoto)
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.5),
                        shape: BoxShape.circle,
                      ),
                      child: const Center(
                        child: CircularProgressIndicator(color: Colors.white),
                      ),
                    ),
                  ),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: GestureDetector(
                    onTap: _isUploadingPhoto ? null : _handlePhotoUpload,
                    child: Container(
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(
                        color: AppTheme.primary,
                        shape: BoxShape.circle,
                        border: Border.all(color: AppTheme.surface, width: 2),
                      ),
                      child: const Icon(
                        Icons.camera_alt_rounded,
                        size: 18,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Center(
            child: Text('Tap to update photo', style: AppTheme.labelSmall),
          ),
          const SizedBox(height: 28),

          _buildInputField(
            "First Name",
            "First Name",
            controller: _firstNameController,
          ),
          _buildInputField(
            "Last Name",
            "Last Name",
            controller: _lastNameController,
          ),
          _buildInputField(
            "Username",
            _profile!.user.username,
            isReadOnly: true,
          ),
          _buildInputField("Email", _profile!.user.email, isReadOnly: true),
          _buildInputField(
            "Phone Number",
            "Phone Number",
            controller: _phoneController,
          ),
          _buildInputField(
            "Skill / Occupation",
            "Skill / Occupation",
            controller: _jobTitleController,
          ),

          const SizedBox(height: 4),
          Text(
            "Biography",
            style: AppTheme.labelMedium.copyWith(
              fontWeight: FontWeight.w600,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey[200]!),
            ),
            child: TextField(
              controller: _bioController,
              maxLines: 5,
              style: AppTheme.bodyMedium,
              decoration: InputDecoration(
                hintText: "Write your bio here...",
                hintStyle: AppTheme.bodyMedium.copyWith(
                  color: Colors.grey[400],
                ),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.all(14),
              ),
            ),
          ),

          const SizedBox(height: 28),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: _isUpdatingProfile ? null : _handleProfileUpdate,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: _isUpdatingProfile
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : Text(
                      "Update Profile",
                      style: AppTheme.bodyMedium.copyWith(
                        color: AppTheme.surface,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputField(
    String label,
    String hint, {
    bool isReadOnly = false,
    bool isPassword = false,
    TextEditingController? controller,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: AppTheme.labelMedium.copyWith(
              fontWeight: FontWeight.w600,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 7),
          Container(
            decoration: BoxDecoration(
              color: isReadOnly ? AppTheme.background : AppTheme.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey[200]!),
            ),
            child: TextField(
              controller: controller,
              readOnly: isReadOnly,
              obscureText: isPassword,
              style: AppTheme.bodyMedium.copyWith(
                color: isReadOnly
                    ? AppTheme.textSecondary
                    : AppTheme.textPrimary,
              ),
              decoration: InputDecoration(
                hintText: hint,
                hintStyle: AppTheme.bodyMedium.copyWith(
                  color: Colors.grey[400],
                ),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 14,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
