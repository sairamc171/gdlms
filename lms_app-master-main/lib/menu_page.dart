import 'package:flutter/material.dart';
import 'services/api_service.dart';
import 'enrolled_courses_page.dart';
import 'profile_page.dart';
import 'main.dart';
import 'settings_page.dart';
import 'dashboard_page.dart';
import 'quiz_attempts_page.dart';

class MenuPage extends StatelessWidget {
  const MenuPage({super.key});

  static const Color primaryBrown = Color(0xFF4B2313);

  Future<void> _handleLogout(BuildContext context) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Logout"),
        content: const Text("Are you sure you want to logout?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Logout", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true && context.mounted) {
      // Use apiService.logout() to clear token
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
      color: Colors.white,
      child: Column(
        children: [
          const Divider(height: 1, thickness: 1, color: Colors.black12),
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                const SizedBox(height: 10),
                _buildMenuItem(
                  context,
                  icon: Icons.speed,
                  title: "Dashboard",
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const DashboardPage(),
                    ),
                  ),
                ),
                _buildMenuItem(
                  context,
                  icon: Icons.person,
                  title: "My Profile",
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const ProfilePage(),
                    ),
                  ),
                ),
                _buildMenuItem(
                  context,
                  icon: Icons.school_outlined,
                  title: "Enrolled Courses",
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const EnrolledCoursesPage(),
                    ),
                  ),
                ),
                _buildMenuItem(
                  context,
                  icon: Icons.quiz_outlined,
                  title: "Quiz Attempts",
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const QuizAttemptsPage(),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Divider(
                    thickness: 1,
                    color: Colors.black.withValues(alpha: 0.1),
                  ),
                ),
                _buildMenuItem(
                  context,
                  icon: Icons.settings_outlined,
                  title: "Settings",
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const SettingsPage(),
                    ),
                  ),
                ),
                _buildMenuItem(
                  context,
                  icon: Icons.logout_rounded,
                  title: "Logout",
                  onTap: () => _handleLogout(context),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuItem(
    BuildContext context, {
    required IconData icon,
    required String title,
    bool isActive = false,
    VoidCallback? onTap,
  }) {
    return Container(
      color: isActive ? primaryBrown : Colors.transparent,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 25, vertical: 4),
        leading: Icon(
          icon,
          color: isActive ? Colors.white : primaryBrown,
          size: 28,
        ),
        title: Text(
          title,
          style: TextStyle(
            color: isActive ? Colors.white : Colors.black87,
            fontSize: 18,
            fontWeight: isActive ? FontWeight.bold : FontWeight.w400,
          ),
        ),
        onTap: onTap,
      ),
    );
  }
}
