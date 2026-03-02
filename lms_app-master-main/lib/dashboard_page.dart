import 'package:flutter/material.dart';
import 'app_theme.dart';
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
      backgroundColor: AppTheme.surface,
      appBar: AppBar(
        backgroundColor: AppTheme.surface,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        centerTitle: true,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: AppTheme.divider),
        ),
        title: Image.asset('assets/GD-logo.png', height: 50),
      ),
      body: IndexedStack(index: _selectedIndex, children: _pages),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: AppTheme.surface,
          border: Border(top: BorderSide(color: AppTheme.divider)),
        ),
        child: BottomNavigationBar(
          currentIndex: _selectedIndex,
          selectedItemColor: AppTheme.primary,
          unselectedItemColor: Colors.grey[400],
          backgroundColor: Colors.transparent,
          elevation: 0,
          selectedLabelStyle: AppTheme.navLabelSelected,
          unselectedLabelStyle: AppTheme.navLabelUnselected,
          onTap: (index) => setState(() => _selectedIndex = index),
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.home_outlined),
              activeIcon: Icon(Icons.home),
              label: 'Home',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.menu_book_outlined),
              activeIcon: Icon(Icons.menu_book),
              label: 'Courses',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.person_outline),
              activeIcon: Icon(Icons.person),
              label: 'Menu',
            ),
          ],
        ),
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
            child: CircularProgressIndicator(color: AppTheme.primary),
          )
        : RefreshIndicator(
            onRefresh: _onRefresh,
            color: AppTheme.primary,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Hero header ──────────────────────────────
                  Container(
                    width: double.infinity,
                    color: AppTheme.surface,
                    padding: const EdgeInsets.fromLTRB(24, 28, 24, 32),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _isLoadingPhoto
                            ? Container(
                                width: 64,
                                height: 64,
                                decoration: const BoxDecoration(
                                  color: AppTheme.placeholder,
                                  shape: BoxShape.circle,
                                ),
                                child: const Center(
                                  child: CircularProgressIndicator(
                                    color: AppTheme.primary,
                                    strokeWidth: 2,
                                  ),
                                ),
                              )
                            : _buildAvatar(initials, 32),

                        const SizedBox(height: 18),

                        Text("Welcome back,", style: AppTheme.welcomeSub),
                        const SizedBox(height: 2),
                        Text(_displayName, style: AppTheme.headingLarge),
                      ],
                    ),
                  ),

                  // ── Stats section ────────────────────────────
                  Container(
                    color: AppTheme.background,
                    padding: const EdgeInsets.fromLTRB(20, 28, 20, 40),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("OVERVIEW", style: AppTheme.overline),
                        const SizedBox(height: 16),

                        // Primary large card
                        _buildPrimaryStatCard(
                          label: "Enrolled Courses",
                          count: stats['enrolled']!,
                        ),

                        const SizedBox(height: 12),

                        Row(
                          children: [
                            Expanded(
                              child: _buildSecondaryStatCard(
                                label: "In Progress",
                                count: stats['active']!,
                                accent: AppTheme.inProgress,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _buildSecondaryStatCard(
                                label: "Completed",
                                count: stats['completed']!,
                                accent: AppTheme.completed,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
  }

  Widget _buildAvatar(String initials, double radius) {
    if (_profilePhotoUrl != null) {
      return ClipOval(
        child: Image.network(
          _profilePhotoUrl!,
          width: radius * 2,
          height: radius * 2,
          fit: BoxFit.cover,
          headers: const {
            'Cache-Control': 'no-cache, no-store, must-revalidate',
            'Pragma': 'no-cache',
          },
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return Container(
              width: radius * 2,
              height: radius * 2,
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
              _initialsAvatar(initials, radius),
        ),
      );
    }
    return _initialsAvatar(initials, radius);
  }

  Widget _initialsAvatar(String initials, double radius) {
    return CircleAvatar(
      radius: radius,
      backgroundColor: AppTheme.primary,
      child: Text(
        initials,
        style: AppTheme.bodyMedium.copyWith(
          fontSize: radius * 0.7,
          fontWeight: FontWeight.w600,
          color: AppTheme.surface,
        ),
      ),
    );
  }

  Widget _buildPrimaryStatCard({required String label, required int count}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(22, 22, 22, 22),
      decoration: AppTheme.primaryCardDecoration,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(count.toString(), style: AppTheme.displayLarge),
                const SizedBox(height: 4),
                Text(
                  label,
                  style: AppTheme.labelMedium.copyWith(
                    color: AppTheme.surface.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppTheme.surface.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.collections_bookmark_outlined,
              color: AppTheme.surface,
              size: 24,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSecondaryStatCard({
    required String label,
    required int count,
    required Color accent,
  }) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
      decoration: AppTheme.cardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: accent,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 14),
          Text(count.toString(), style: AppTheme.statCount),
          const SizedBox(height: 4),
          Text(label, style: AppTheme.labelSmall),
        ],
      ),
    );
  }
}
