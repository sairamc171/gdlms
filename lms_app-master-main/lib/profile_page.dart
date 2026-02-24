import 'package:flutter/material.dart';
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

    // Clear image cache so the latest photo always loads fresh
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
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Logout'),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      await apiService.logout();
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const LoginPage()),
        (route) => false,
      );
    }
  }

  String _formatDate(String dateString) {
    try {
      final date = DateTime.parse(dateString);
      return DateFormat('MMMM dd, yyyy h:mm a').format(date);
    } catch (e) {
      return dateString;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFF6D391E)),
        ),
      );
    }

    if (_profile == null) {
      return Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          title: const Text('My Profile'),
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          elevation: 0,
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.grey),
              const SizedBox(height: 16),
              const Text(
                'Failed to load profile',
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _loadProfile,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6D391E),
                  foregroundColor: Colors.white,
                ),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('My Profile'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.red),
            onPressed: _handleLogout,
            tooltip: 'Logout',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadProfile,
        color: const Color(0xFF6D391E),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            children: [
              const SizedBox(height: 24),
              _buildProfileHeader(),
              const SizedBox(height: 24),
              _buildInfoCard(),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProfileHeader() {
    final String photoUrl = _profile!.user.profilePhoto;
    final bool hasPhoto = photoUrl.isNotEmpty;
    // Unique timestamp per load so Flutter cannot serve a cached version
    final String photoUrlWithBust = hasPhoto
        ? '$photoUrl?nocache=${DateTime.now().millisecondsSinceEpoch}'
        : '';

    final String initial = _profile!.user.firstName.isNotEmpty
        ? _profile!.user.firstName[0].toUpperCase()
        : _profile!.user.username.isNotEmpty
        ? _profile!.user.username[0].toUpperCase()
        : 'U';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          // Use ClipOval + Image.network for full cache-control header support
          hasPhoto
              ? ClipOval(
                  child: Image.network(
                    photoUrlWithBust,
                    width: 120,
                    height: 120,
                    fit: BoxFit.cover,
                    headers: const {
                      'Cache-Control': 'no-cache, no-store, must-revalidate',
                      'Pragma': 'no-cache',
                    },
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return Container(
                        width: 120,
                        height: 120,
                        color: Colors.grey[200],
                        child: const Center(
                          child: CircularProgressIndicator(
                            color: Color(0xFF6D391E),
                            strokeWidth: 2,
                          ),
                        ),
                      );
                    },
                    errorBuilder: (context, error, stackTrace) {
                      return _initialsAvatar(initial, 60);
                    },
                  ),
                )
              : _initialsAvatar(initial, 60),
          const SizedBox(height: 16),
          Text(
            '${_profile!.user.firstName} ${_profile!.user.lastName}'.trim(),
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          if (_profile!.user.jobTitle.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                _profile!.user.jobTitle,
                style: TextStyle(fontSize: 16, color: Colors.grey[600]),
              ),
            ),
        ],
      ),
    );
  }

  Widget _initialsAvatar(String initial, double radius) {
    return CircleAvatar(
      radius: radius,
      backgroundColor: const Color(0xFF6D391E),
      child: Text(
        initial,
        style: TextStyle(
          fontSize: radius * 0.8,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
    );
  }

  Widget _buildInfoCard() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        children: [
          _buildInfoRow(
            'Registration Date',
            _formatDate(_profile!.user.registeredDate),
            Icons.calendar_today,
          ),
          _buildDivider(),
          _buildInfoRow('First Name', _profile!.user.firstName, Icons.person),
          _buildDivider(),
          _buildInfoRow(
            'Last Name',
            _profile!.user.lastName,
            Icons.person_outline,
          ),
          _buildDivider(),
          _buildInfoRow(
            'Username',
            _profile!.user.username,
            Icons.account_circle,
          ),
          _buildDivider(),
          _buildInfoRow('Email', _profile!.user.email, Icons.email),
          _buildDivider(),
          _buildInfoRow(
            'Phone Number',
            _profile!.user.phone.isEmpty ? '-' : _profile!.user.phone,
            Icons.phone,
          ),
          _buildDivider(),
          _buildInfoRow(
            'Skill/Occupation',
            _profile!.user.jobTitle.isEmpty
                ? 'Student'
                : _profile!.user.jobTitle,
            Icons.work,
          ),
          _buildDivider(),
          _buildInfoRow(
            'Biography',
            _profile!.user.bio.isEmpty ? '-' : _profile!.user.bio,
            Icons.info,
            isMultiline: true,
          ),
        ],
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
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: Colors.grey[600]),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              fontSize: 16,
              color: Colors.black87,
              fontWeight: FontWeight.w500,
            ),
            maxLines: isMultiline ? null : 1,
            overflow: isMultiline ? null : TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildDivider() {
    return Divider(
      height: 1,
      thickness: 1,
      color: Colors.grey[200],
      indent: 20,
      endIndent: 20,
    );
  }
}
