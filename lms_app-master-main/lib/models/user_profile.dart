class UserProfile {
  final User user;
  final Social social;
  final Stats stats;

  UserProfile({required this.user, required this.social, required this.stats});

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      user: User.fromJson(json['user'] ?? {}),
      social: Social.fromJson(json['social'] ?? {}),
      stats: Stats.fromJson(json['stats'] ?? {}),
    );
  }
}

class User {
  final int id;
  final String username;
  final String email;
  final String displayName;
  final String firstName;
  final String lastName;
  final String fullName;
  final String phone;
  final String bio;
  final String jobTitle;
  final String registeredDate;
  final String profilePhoto;
  final String role;

  User({
    required this.id,
    required this.username,
    required this.email,
    required this.displayName,
    required this.firstName,
    required this.lastName,
    required this.fullName,
    required this.phone,
    required this.bio,
    required this.jobTitle,
    required this.registeredDate,
    required this.profilePhoto,
    required this.role,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] ?? 0,
      username: json['username'] ?? '',
      email: json['email'] ?? '',
      displayName: json['display_name'] ?? '',
      firstName: json['first_name'] ?? '',
      lastName: json['last_name'] ?? '',
      fullName: json['full_name'] ?? '',
      phone: json['phone'] ?? '',
      bio: json['bio'] ?? '',
      jobTitle: json['job_title'] ?? '',
      registeredDate: json['registered_date'] ?? '',
      profilePhoto: json['profile_photo'] ?? '',
      role: json['role'] ?? '',
    );
  }
}

class Social {
  final String facebook;
  final String twitter;
  final String linkedin;
  final String website;

  Social({
    required this.facebook,
    required this.twitter,
    required this.linkedin,
    required this.website,
  });

  factory Social.fromJson(Map<String, dynamic> json) {
    return Social(
      facebook: json['facebook'] ?? '',
      twitter: json['twitter'] ?? '',
      linkedin: json['linkedin'] ?? '',
      website: json['website'] ?? '',
    );
  }
}

class Stats {
  final int enrolledCourses;
  final int completedCourses;
  final int activeCourses;
  final int completedLessons;
  final int certificates;

  Stats({
    required this.enrolledCourses,
    required this.completedCourses,
    required this.activeCourses,
    required this.completedLessons,
    required this.certificates,
  });

  factory Stats.fromJson(Map<String, dynamic> json) {
    return Stats(
      enrolledCourses: json['enrolled_courses'] ?? 0,
      completedCourses: json['completed_courses'] ?? 0,
      activeCourses: json['active_courses'] ?? 0,
      completedLessons: json['completed_lessons'] ?? 0,
      certificates: json['certificates'] ?? 0,
    );
  }

  double get completionRate {
    if (enrolledCourses == 0) return 0.0;
    return (completedCourses / enrolledCourses) * 100;
  }
}
