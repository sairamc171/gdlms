import 'package:flutter/material.dart';
import 'services/api_service.dart';
import 'enrolled_courses_page.dart';
import 'menu_page.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  int _selectedIndex = 0;

  final List<Widget> _pages = [
    const DashboardHomeContent(),
    const EnrolledCoursesPage(),
    const MenuPage(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        title: Image.asset('assets/GD-logo.png', height: 50),
      ),
      body: IndexedStack(index: _selectedIndex, children: _pages),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        selectedItemColor: const Color(0xFF4B2313),
        unselectedItemColor: Colors.grey,
        onTap: (index) => setState(() => _selectedIndex = index),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.book), label: 'Courses'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Menu'),
        ],
      ),
    );
  }
}

class DashboardHomeContent extends StatefulWidget {
  const DashboardHomeContent({super.key});

  @override
  State<DashboardHomeContent> createState() => _DashboardHomeContentState();
}

class _DashboardHomeContentState extends State<DashboardHomeContent> {
  Map<String, int> stats = {'enrolled': 0, 'active': 0, 'completed': 0};
  bool _isLoadingStats = true;
  bool _isLoadingPhoto = true;
  String? _profilePhotoUrl;
  String _displayName = "Student";

  String _getInitials(String name) {
    if (name.isEmpty) return "S";
    List<String> parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length > 1) {
      return (parts[0][0] + parts[parts.length - 1][0]).toUpperCase();
    }
    return parts[0][0].toUpperCase();
  }

  @override
  void initState() {
    super.initState();
    _loadStats();
    _loadProfile();
  }

  Future<void> _loadStats() async {
    if (!mounted) return;
    setState(() => _isLoadingStats = true);
    try {
      final List<dynamic> courses = await apiService.getEnrolledCourses();
      if (mounted) {
        int enrolledCount = courses.length;
        int finishedCount = 0;
        int inProgressCount = 0;
        for (var course in courses) {
          num progress = course['progress'] ?? 0;
          if (progress >= 100) {
            finishedCount++;
          } else {
            inProgressCount++;
          }
        }
        setState(() {
          stats = {
            'enrolled': enrolledCount,
            'active': inProgressCount,
            'completed': finishedCount,
          };
          _isLoadingStats = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingStats = false);
    }
  }

  Future<void> _loadProfile() async {
    if (!mounted) return;
    setState(() => _isLoadingPhoto = true);
    try {
      final data = await apiService.getUserProfile();
      if (data != null && mounted) {
        final String rawPhoto =
            (data['user']?['profile_photo'] as String?) ?? '';
        final String firstName = (data['user']?['first_name'] as String?) ?? '';
        final String lastName = (data['user']?['last_name'] as String?) ?? '';
        final String displayName =
            (data['user']?['display_name'] as String?) ?? '';

        String name = '';
        if (firstName.isNotEmpty || lastName.isNotEmpty) {
          name = '$firstName $lastName'.trim();
        } else if (displayName.isNotEmpty) {
          name = displayName;
        } else {
          name = apiService.user?['user_display_name'] ?? 'Student';
        }

        // Clear Flutter's entire image cache so no stale photo is served
        imageCache.clear();
        imageCache.clearLiveImages();

        if (mounted) {
          setState(() {
            _profilePhotoUrl = rawPhoto.isNotEmpty
                ? '$rawPhoto?nocache=${DateTime.now().millisecondsSinceEpoch}'
                : null;
            _displayName = name;
            _isLoadingPhoto = false;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _displayName = apiService.user?['user_display_name'] ?? 'Student';
            _isLoadingPhoto = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _displayName = apiService.user?['user_display_name'] ?? 'Student';
          _isLoadingPhoto = false;
        });
      }
    }
  }

  Future<void> _onRefresh() async {
    await Future.wait([_loadStats(), _loadProfile()]);
  }

  @override
  Widget build(BuildContext context) {
    final String initials = _getInitials(_displayName);

    return _isLoadingStats
        ? const Center(
            child: CircularProgressIndicator(color: Color(0xFF4B2313)),
          )
        : RefreshIndicator(
            onRefresh: _onRefresh,
            color: const Color(0xFF4B2313),
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(24),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const Text(
                      "Dashboard",
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 25),
                    _isLoadingPhoto
                        ? Container(
                            width: 90,
                            height: 90,
                            decoration: BoxDecoration(
                              color: Colors.grey[200],
                              shape: BoxShape.circle,
                            ),
                            child: const Center(
                              child: CircularProgressIndicator(
                                color: Color(0xFF4B2313),
                                strokeWidth: 3,
                              ),
                            ),
                          )
                        : _buildAvatar(initials),
                    const SizedBox(height: 12),
                    Text(
                      "Welcome back, $_displayName",
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.grey,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 40),
                    _buildStatCard(
                      "Enrolled Courses",
                      stats['enrolled']!,
                      Icons.collections_bookmark,
                      const Color(0xFF4B2313),
                    ),
                    _buildStatCard(
                      "In Progress",
                      stats['active']!,
                      Icons.play_lesson,
                      Colors.orange,
                    ),
                    _buildStatCard(
                      "Finished",
                      stats['completed']!,
                      Icons.check_circle,
                      Colors.green,
                    ),
                  ],
                ),
              ),
            ),
          );
  }

  Widget _buildAvatar(String initials) {
    if (_profilePhotoUrl != null) {
      return ClipOval(
        child: Image.network(
          _profilePhotoUrl!,
          width: 90,
          height: 90,
          fit: BoxFit.cover,
          headers: const {
            'Cache-Control': 'no-cache, no-store, must-revalidate',
            'Pragma': 'no-cache',
          },
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return Container(
              width: 90,
              height: 90,
              color: Colors.grey[200],
              child: Center(
                child: CircularProgressIndicator(
                  color: const Color(0xFF4B2313),
                  strokeWidth: 2,
                  value: loadingProgress.expectedTotalBytes != null
                      ? loadingProgress.cumulativeBytesLoaded /
                            loadingProgress.expectedTotalBytes!
                      : null,
                ),
              ),
            );
          },
          errorBuilder: (context, error, stackTrace) {
            return Container(
              width: 90,
              height: 90,
              decoration: const BoxDecoration(
                color: Color(0xFF4B2313),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  initials,
                  style: const TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFF9F3E7),
                  ),
                ),
              ),
            );
          },
        ),
      );
    }

    return CircleAvatar(
      radius: 45,
      backgroundColor: const Color(0xFF4B2313),
      child: Text(
        initials,
        style: const TextStyle(
          fontSize: 32,
          fontWeight: FontWeight.bold,
          color: Color(0xFFF9F3E7),
        ),
      ),
    );
  }

  Widget _buildStatCard(String title, int count, IconData icon, Color color) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFF9F3E7),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.1)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 26),
          ),
          const SizedBox(width: 20),
          Text(
            title,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          const Spacer(),
          Text(
            count.toString(),
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
