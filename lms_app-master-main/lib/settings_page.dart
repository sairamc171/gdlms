import 'package:flutter/material.dart';
import 'dashboard_page.dart';


class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});


  @override
  State<SettingsPage> createState() => _SettingsPageState();
}


class _SettingsPageState extends State<SettingsPage> with SingleTickerProviderStateMixin {
  final Color primaryBrown = const Color(0xFF6D391E);
  late TabController _tabController;


  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }


  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
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
          style: TextStyle(color: Colors.black, fontSize: 24, fontWeight: FontWeight.bold),
        ),
      ),
      body: Column(
        children: [
          Container(
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: Colors.black12, width: 1)),
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
              children: [
                _buildProfileTab(),   // Index 0
                _buildPasswordTab(),  // Index 1
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        selectedItemColor: primaryBrown,
        unselectedItemColor: Colors.grey,
        currentIndex: 2,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.speed), label: "Dashboard"),
          BottomNavigationBarItem(icon: Icon(Icons.extension), label: "Quiz Attempts"),
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


  // --- PASSWORD TAB BUILDER ---
  Widget _buildPasswordTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildInputField("Current Password", "Current Password", isPassword: true),
          _buildInputField("New Password", "Type Password", isPassword: true),
          _buildInputField("Re-type New Password", "Type Password", isPassword: true),
          const SizedBox(height: 24),
          Center(
            child: SizedBox(
              width: 180,
              height: 50,
              child: ElevatedButton(
                onPressed: () {},
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryBrown,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: const Text(
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


  // --- PROFILE TAB BUILDER ---
  Widget _buildProfileTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // --- PROFILE & COVER PHOTO SECTION ---
          Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              // Cover Photo Container
              GestureDetector(
                onTap: () => debugPrint("Update Cover Photo"),
                child: Container(
                  height: 150,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(12),
                    image: const DecorationImage(
                      image: NetworkImage('https://via.placeholder.com/600x200'), // Replace with actual logic
                      fit: BoxFit.cover,
                    ),
                  ),
                  child: const Align(
                    alignment: Alignment.bottomRight,
                    child: Padding(
                      padding: EdgeInsets.all(8.0),
                      child: CircleAvatar(
                        backgroundColor: Colors.white,
                        radius: 18,
                        child: Icon(Icons.camera_alt, size: 18, color: Colors.black),
                      ),
                    ),
                  ),
                ),
              ),
              // Profile Photo
              Positioned(
                bottom: -50,
                child: GestureDetector(
                  onTap: () => print("Update Profile Photo"),
                  child: Stack(
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 4),
                        ),
                        child: CircleAvatar(
                          radius: 50,
                          backgroundColor: Colors.grey[400],
                          backgroundImage: const NetworkImage('https://via.placeholder.com/150'), // Replace with actual logic
                        ),
                      ),
                      const Positioned(
                        bottom: 5,
                        right: 5,
                        child: CircleAvatar(
                          backgroundColor: Colors.white,
                          radius: 15,
                          child: Icon(Icons.camera_alt, size: 15, color: Colors.black),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 60), // Space for the floating profile image


          const Text("Profile Photo Size: 200x200 pixels", style: TextStyle(fontSize: 12, color: Colors.grey)),
          const Text("Cover Photo Size: 700x430 pixels", style: TextStyle(fontSize: 12, color: Colors.grey)),
          const SizedBox(height: 30),


          _buildInputField("First Name", "Monish"),
          _buildInputField("Last Name", "M"),
          _buildInputField("User Name", "monish.m@chakraview.co", isReadOnly: true),
          _buildInputField("Phone Number", "Phone Number"),
          _buildInputField("Skill/Occupation", "Student"),
          const Text("Timezone", style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          _buildDropdownField("Abidjan"),
          const SizedBox(height: 24),
          const Text("Bio", style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          _buildBioEditor(),
          const SizedBox(height: 24),
          const Text("Display name publicly as", style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          _buildDropdownField("Monish M"),
          const SizedBox(height: 32),
          Center(
            child: SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: () {},
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryBrown,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: const Text("Update Profile", style: TextStyle(color: Colors.white)),
              ),
            ),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }


  // --- REUSABLE FIELD WIDGETS ---
  Widget _buildInputField(String label, String hint, {bool isReadOnly = false, bool isPassword = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          TextField(
            readOnly: isReadOnly,
            obscureText: isPassword,
            decoration: InputDecoration(
              filled: isReadOnly,
              fillColor: isReadOnly ? Colors.grey[200] : Colors.transparent,
              hintText: hint,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12),
            ),
          ),
        ],
      ),
    );
  }


  Widget _buildDropdownField(String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.black38),
        borderRadius: BorderRadius.circular(8),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          isExpanded: true,
          value: value,
          items: [DropdownMenuItem(value: value, child: Text(value))],
          onChanged: (v) {},
        ),
      ),
    );
  }


  Widget _buildBioEditor() {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.black38),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Container(
            color: Colors.grey[100],
            padding: const EdgeInsets.all(8),
            child: const Row(
              children: [
                Icon(Icons.format_bold, size: 20), SizedBox(width: 15),
                Icon(Icons.format_italic, size: 20), SizedBox(width: 15),
                Icon(Icons.format_underlined, size: 20), SizedBox(width: 15),
                Icon(Icons.format_quote, size: 20), SizedBox(width: 15),
                Icon(Icons.format_list_bulleted, size: 20), SizedBox(width: 15),
                Icon(Icons.format_list_numbered, size: 20), SizedBox(width: 15),
                Icon(Icons.format_align_left, size: 20),
              ],
            ),
          ),
          const TextField(
            maxLines: 5,
            decoration: InputDecoration(
              border: InputBorder.none,
              contentPadding: EdgeInsets.all(10),
              hintText: "Write your bio here...",
            ),
          ),
        ],
      ),
    );
  }
}

