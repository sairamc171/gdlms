import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
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
  final Color primaryBrown = const Color(0xFF6D391E);
  late TabController _tabController;

  UserProfile? _profile;
  bool _isLoadingProfile = true;
  bool _isUploadingPhoto = false;
  // Separate cache-bust key so we can force image reload after upload
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
          title: const Text('Choose Photo Source'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.camera_alt),
                title: const Text('Camera'),
                onTap: () => Navigator.pop(context, ImageSource.camera),
              ),
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: const Text('Gallery'),
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
        // Bump the cache-bust key BEFORE reloading so the new image
        // is always fetched fresh from the server
        setState(() {
          _photoCacheBust = DateTime.now().millisecondsSinceEpoch;
          _isUploadingPhoto = false;
        });
        _showSuccess('Profile photo updated successfully!');
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
      _showError("Password must be at least 8 characters long");
      return;
    }
    final hasNumber = RegExp(r'[0-9]').hasMatch(newPass);
    final hasSpecial = RegExp(r'[!@#$%^&*(),.?":{}|<>]').hasMatch(newPass);
    if (!hasNumber || !hasSpecial) {
      _showError(
        "Password must include at least one number and one special character",
      );
      return;
    }
    if (currentPass == newPass) {
      _showError("New password cannot be the same as your current password");
      return;
    }
    if (newPass != confirmPass) {
      _showError("New passwords do not match!");
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
    final profileData = {
      'first_name': _firstNameController.text,
      'last_name': _lastNameController.text,
      'phone': _phoneController.text,
      'job_title': _jobTitleController.text,
      'bio': _bioController.text,
    };

    try {
      final success = await apiService.updateUserProfile(profileData);
      if (!mounted) return;
      setState(() => _isUpdatingProfile = false);
      if (success) {
        _showSuccess("Profile updated successfully!");
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

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.green),
    );
  }

  /// Returns the photo URL with a cache-bust query param.
  /// Uses _photoCacheBust if set (after upload), otherwise uses
  /// the current timestamp so stale cached images are never shown.
  String _buildPhotoUrl(String baseUrl) {
    final bust = _photoCacheBust > 0
        ? _photoCacheBust
        : DateTime.now().millisecondsSinceEpoch;
    return '$baseUrl?v=$bust';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          "Settings",
          style: TextStyle(
            color: Colors.black,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: _isLoadingProfile
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF6D391E)),
            )
          : Column(
              children: [
                Container(
                  decoration: const BoxDecoration(
                    border: Border(
                      bottom: BorderSide(color: Colors.black12, width: 1),
                    ),
                  ),
                  child: TabBar(
                    controller: _tabController,
                    indicatorColor: primaryBrown,
                    labelColor: primaryBrown,
                    unselectedLabelColor: Colors.black54,
                    tabs: const [
                      Tab(text: "Profile"),
                      Tab(text: "Password"),
                    ],
                  ),
                ),
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
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildInputField(
            "Current Password",
            "Current Password",
            isPassword: true,
            controller: _currentPasswordController,
          ),
          _buildInputField(
            "New Password",
            "Type Password",
            isPassword: true,
            controller: _newPasswordController,
          ),
          _buildInputField(
            "Re-type New Password",
            "Type Password",
            isPassword: true,
            controller: _confirmPasswordController,
          ),
          const SizedBox(height: 24),
          Center(
            child: SizedBox(
              width: 180,
              height: 50,
              child: ElevatedButton(
                onPressed: _isResetting ? null : _handlePasswordReset,
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryBrown,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: _isResetting
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Text(
                        "Reset Password",
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white, fontSize: 16),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileTab() {
    if (_profile == null) {
      return const Center(child: Text('Failed to load profile'));
    }

    final String photoUrl = _profile!.user.profilePhoto;
    final bool hasPhoto = photoUrl.isNotEmpty;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Profile Photo Section — single CircleAvatar, no nesting
          Center(
            child: Stack(
              children: [
                CircleAvatar(
                  radius: 60,
                  // Light grey while photo loads; brown for initials fallback
                  backgroundColor: hasPhoto ? Colors.grey[200] : primaryBrown,
                  backgroundImage: hasPhoto
                      ? NetworkImage(_buildPhotoUrl(photoUrl))
                      : null,
                  onBackgroundImageError: hasPhoto
                      ? (_, __) {
                          // Photo failed — fall back to initials
                          if (mounted) setState(() {});
                        }
                      : null,
                  child: !hasPhoto
                      ? Text(
                          _profile!.user.firstName.isNotEmpty
                              ? _profile!.user.firstName[0].toUpperCase()
                              : 'U',
                          style: const TextStyle(
                            fontSize: 48,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        )
                      : null,
                ),

                // Upload progress overlay
                if (_isUploadingPhoto)
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.5),
                        shape: BoxShape.circle,
                      ),
                      child: const Center(
                        child: CircularProgressIndicator(color: Colors.white),
                      ),
                    ),
                  ),

                // Camera button
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: GestureDetector(
                    onTap: _isUploadingPhoto ? null : _handlePhotoUpload,
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: primaryBrown,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                      child: const Icon(
                        Icons.camera_alt,
                        size: 20,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          const Center(
            child: Text(
              'Tap camera icon to upload photo',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ),
          const SizedBox(height: 30),

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
            "User Name",
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
            "Skill/Occupation",
            "Skill/Occupation",
            controller: _jobTitleController,
          ),
          const SizedBox(height: 20),
          const Text(
            "Bio",
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _bioController,
            maxLines: 5,
            decoration: InputDecoration(
              hintText: "Write your bio here...",
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              contentPadding: const EdgeInsets.all(12),
            ),
          ),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: _isUpdatingProfile ? null : _handleProfileUpdate,
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryBrown,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: _isUpdatingProfile
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Text(
                      "Update Profile",
                      style: TextStyle(color: Colors.white, fontSize: 16),
                    ),
            ),
          ),
          const SizedBox(height: 40),
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
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: controller,
            readOnly: isReadOnly,
            obscureText: isPassword,
            decoration: InputDecoration(
              filled: isReadOnly,
              fillColor: isReadOnly ? Colors.grey[200] : Colors.transparent,
              hintText: hint,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 16,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
