import 'package:flutter/material.dart';
import 'dashboard_page.dart';

class MyProfilePage extends StatelessWidget {
  final Color primaryBrown = const Color(0xFF6D391E);

  // Example static data - in a real app, fetch this from your WordPress/LMS Service
  final String registrationDate = "January 26, 2026 4:29 pm";
  final String firstName = "Monish";
  final String lastName = "M";
  final String username = "monish.m@chakraview.co";
  final String email = "monish.m@chakraview.co";
  final String phoneNumber = "-";
  final String occupation = "Student";
  final String biography = "-";

  const MyProfilePage({super.key});

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
          "My Profile",
          style: TextStyle(
            color: Colors.black,
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: Column(
        children: [
          const Divider(thickness: 1, height: 1),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                _buildProfileInfo(
                  "Registration Date",
                  registrationDate,
                  isBold: true,
                ),
                _buildProfileInfo("First Name", firstName, isBold: true),
                _buildProfileInfo("Last Name", lastName, isBold: true),
                _buildProfileInfo("Username", username, isBold: true),
                _buildProfileInfo("Email", email, isBold: true),
                _buildProfileInfo("Phone Number", phoneNumber, isBold: false),
                _buildProfileInfo("Skill/Occupation", occupation, isBold: true),
                _buildProfileInfo("Biography", biography, isBold: false),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        selectedItemColor: primaryBrown,
        unselectedItemColor: Colors.grey,
        currentIndex: 2, // Highlight Menu
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.speed), label: "Dashboard"),
          BottomNavigationBarItem(
            icon: Icon(Icons.extension),
            label: "Quiz Attempts",
          ),
          BottomNavigationBarItem(icon: Icon(Icons.menu), label: "Menu"),
        ],
        onTap: (index) {
          if (index == 0) {
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(builder: (context) => const DashboardPage()),
              (route) => false,
            );
          } else {
            Navigator.pop(context);
          }
        },
      ),
    );
  }

  Widget _buildProfileInfo(String label, String value, {required bool isBold}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 25),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(color: Colors.black54, fontSize: 16),
          ),
          const SizedBox(height: 5),
          Text(
            value,
            style: TextStyle(
              color: Colors.black87,
              fontSize: 18,
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }
}
