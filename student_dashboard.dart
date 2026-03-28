import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'student_profile_page.dart';
import 'teacher_detail_page.dart';

class StudentDashboard extends StatefulWidget {
  const StudentDashboard({super.key});

  @override
  State<StudentDashboard> createState() => _StudentDashboardState();
}

class _StudentDashboardState extends State<StudentDashboard> {
  final user = FirebaseAuth.instance.currentUser;
  final dbRef = FirebaseDatabase.instance.ref();
  bool isLoading = false;
  Map<String, dynamic>? userData;
  List<Map<String, dynamic>> teachers = [];
  List<Map<String, dynamic>> pendingRequests = [];
  List<Map<String, dynamic>> acceptedRequests = [];
  List<Map<String, dynamic>> rejectedRequests = [];
  String searchQuery = "";
  int selectedTab = 0;

  @override
  void initState() {
    super.initState();
    loadUserData();
    loadTeachers();
    loadAllRequests();
    if (user != null) {
      dbRef
          .child("student_requests")
          .child(user!.uid)
          .onValue
          .listen((event) {
        if (event.snapshot.exists && mounted) {
          _processRequests(event.snapshot.value as Map);
        } else if (mounted) {
          setState(() {
            pendingRequests = [];
            acceptedRequests = [];
            rejectedRequests = [];
          });
        }
      });
    }
  }

  void _processRequests(Map<dynamic, dynamic> data) {
    List<Map<String, dynamic>> pending = [];
    List<Map<String, dynamic>> accepted = [];
    List<Map<String, dynamic>> rejected = [];
    data.forEach((key, value) {
      final requestData = Map<String, dynamic>.from(value as Map);
      final request = {
        "requestId": key,
        "teacherName": requestData['teacherName'] ?? "Teacher",
        "teacherId": requestData['teacherId'] ?? "",
        "timeSlot": requestData['timeSlot'] ?? "",
        "period": requestData['period'] ?? "",
        "day": requestData['day'] ?? "",
        "purpose": requestData['purpose'] ?? "",
        "status": requestData['status'] ?? "pending",
        "createdAt": requestData['createdAt'] ?? "",
      };
      if (request['status'] == 'pending') {
        pending.add(request);
      } else if (request['status'] == 'accepted') {
        accepted.add(request);
      } else if (request['status'] == 'rejected') {
        rejected.add(request);
      }
    });
    if (mounted) {
      setState(() {
        pendingRequests = pending;
        acceptedRequests = accepted;
        rejectedRequests = rejected;
      });
    }
  }

  Future<void> loadUserData() async {
    if (user == null) return;
    try {
      final snapshot = await dbRef.child("users/${user!.uid}").get();
      if (snapshot.exists && mounted) {
        setState(() {
          userData = Map<String, dynamic>.from(snapshot.value as Map);
        });
      }
    } catch (e) {
      debugPrint("Error loading user data: $e");
    }
  }

  Future<void> loadTeachers() async {
    try {
      final snapshot = await dbRef.child("users").get();
      if (snapshot.exists && mounted) {
        final data = snapshot.value as Map<dynamic, dynamic>;
        final List<Map<String, dynamic>> temp = [];
        data.forEach((key, value) {
          final userData = Map<String, dynamic>.from(value as Map);
          final bool isActive = userData['isActive'] == null || userData['isActive'] == true;
          if (userData['role'] == "teacher" && isActive) {
            temp.add({
              "uid": key,
              "name": userData['name'] ?? "Unknown",
              "subject": userData['subject'] ?? "General",
              "email": userData['email'] ?? "",
              "branch": userData['branch'] ?? "",
              "roomNo": userData['roomNo'] ?? "",
              "phone": userData['phone'] ?? "",
              "profileImageUrl": userData['profileImageUrl'],
            });
          }
        });
        if (mounted) {
          setState(() => teachers = temp);
        }
      }
    } catch (e) {
      debugPrint("Error loading teachers: $e");
    }
  }

  Future<void> loadAllRequests() async {
    if (user == null) return;
    try {
      final snapshot = await dbRef
          .child("student_requests")
          .child(user!.uid)
          .get();
      if (snapshot.exists && mounted) {
        _processRequests(snapshot.value as Map);
      }
    } catch (e) {
      debugPrint("Error loading requests: $e");
    }
  }

  Future<void> cancelRequest(Map<String, dynamic> request) async {
    if (user == null) return;
    setState(() => isLoading = true);
    try {
      await dbRef
          .child("student_requests")
          .child(user!.uid)
          .child(request['requestId'])
          .remove();
      await dbRef
          .child("teacher_requests")
          .child(request['teacherId'])
          .child(request['requestId'])
          .remove();
      await dbRef
          .child("appointment_requests")
          .child(request['requestId'])
          .remove();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Request cancelled successfully"),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Error cancelling request: ${e.toString()}"),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  Future<void> _logout() async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Logout"),
        content: const Text("Are you sure you want to logout?"),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              setState(() => isLoading = true);
              await FirebaseAuth.instance.signOut();
              if (mounted) {
                Navigator.pushNamedAndRemoveUntil(context, '/role-selection', (route) => false);
              }
            },
            child: const Text("Logout", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filtered = teachers
        .where((t) => t['name'].toLowerCase().contains(searchQuery.toLowerCase()))
        .toList();
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        title: const Text(
          "Student Dashboard",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Container(
            color: Colors.white,
            child: Row(
              children: [
                _buildTabButton("Teachers", 0),
                _buildTabButton("Pending (${pendingRequests.length})", 1),
                _buildTabButton("Accepted (${acceptedRequests.length})", 2),
                _buildTabButton("Rejected (${rejectedRequests.length})", 3),
              ],
            ),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              loadTeachers();
              loadAllRequests();
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text("Refreshing..."),
                    duration: Duration(seconds: 1),
                  ),
                );
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.person),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const StudentProfilePage()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _logout,
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : selectedTab == 0
              ? _buildTeachersTab(filtered)
              : selectedTab == 1
                  ? _buildRequestsTab(pendingRequests, "pending")
                  : selectedTab == 2
                      ? _buildRequestsTab(acceptedRequests, "accepted")
                      : _buildRequestsTab(rejectedRequests, "rejected"),
    );
  }

  Widget _buildTabButton(String title, int index) {
    final isSelected = selectedTab == index;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            selectedTab = index;
          });
        },
        child: Container(
          height: 48,
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: isSelected ? Colors.blue.shade700 : Colors.transparent,
                width: 2,
              ),
            ),
          ),
          child: Center(
            child: Text(
              title,
              style: TextStyle(
                color: isSelected ? Colors.blue.shade700 : Colors.grey.shade600,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                fontSize: 12,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTeachersTab(List<Map<String, dynamic>> filtered) {
    return RefreshIndicator(
      onRefresh: () async {
        await loadTeachers();
        await loadAllRequests();
      },
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.blue.shade700, Colors.blue.shade400],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: [
                    const CircleAvatar(
                      radius: 30,
                      backgroundColor: Colors.white,
                      child: Icon(Icons.school, size: 35, color: Colors.blue),
                    ),
                    const SizedBox(width: 15),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Welcome back!",
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.9),
                              fontSize: 14,
                            ),
                          ),
                          Text(
                            userData?['name'] ?? "Student",
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: Text(
                        "${filtered.length} Teachers",
                        style: const TextStyle(color: Colors.white, fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              TextField(
                onChanged: (v) {
                  setState(() => searchQuery = v);
                },
                decoration: InputDecoration(
                  hintText: "Search teachers by name...",
                  prefixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(30),
                    borderSide: BorderSide.none,
                  ),
                  filled: true,
                  fillColor: Colors.white,
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                "Available Teachers",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              filtered.isEmpty
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(50),
                        child: Text("No teachers available"),
                      ),
                    )
                  : ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: filtered.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final teacher = filtered[index];
                        return Card(
                          elevation: 2,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(15),
                          ),
                          child: ListTile(
                            contentPadding: const EdgeInsets.all(12),
                            leading: CircleAvatar(
                              radius: 25,
                              backgroundColor: Colors.blue.shade100,
                              child: Icon(
                                Icons.person,
                                color: Colors.blue.shade700,
                                size: 28,
                              ),
                            ),
                            title: Text(
                              teacher['name'],
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const SizedBox(height: 4),
                                if (teacher['branch'] != null && teacher['branch']!.isNotEmpty)
                                  Text(
                                    teacher['branch'],
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                if (teacher['roomNo'] != null && teacher['roomNo']!.isNotEmpty)
                                  Text(
                                    "Room: ${teacher['roomNo']}",
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                              ],
                            ),
                            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => TeacherDetailPage(teacher: teacher),
                                ),
                              );
                            },
                          ),
                        );
                      },
                    ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRequestsTab(List<Map<String, dynamic>> requests, String type) {
    if (requests.isEmpty) {
      String message = type == "pending" 
          ? "No pending requests" 
          : type == "accepted" 
              ? "No accepted requests" 
              : "No rejected requests";
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inbox_outlined, size: 80, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              message,
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
            if (type == "pending")
              SizedBox(height: 8),
            if (type == "pending")
              Text(
                "Request appointments from teachers during their available time slots",
                style: TextStyle(fontSize: 12, color: Colors.grey),
                textAlign: TextAlign.center,
              ),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: loadAllRequests,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: requests.length,
        itemBuilder: (context, index) {
          final request = requests[index];
          Color statusColor = type == "pending" 
              ? Colors.orange 
              : type == "accepted" 
                  ? Colors.green 
                  : Colors.red;
          IconData statusIcon = type == "pending" 
              ? Icons.pending_actions 
              : type == "accepted" 
                  ? Icons.check_circle 
                  : Icons.cancel;
          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(15),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: statusColor.withValues(alpha: 0.1),
                        child: Icon(statusIcon, color: statusColor),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              request['teacherName'],
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              "${request['day']} - ${request['timeSlot']}",
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: statusColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          request['status'].toUpperCase(),
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: statusColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    "Purpose: ${request['purpose']}",
                    style: TextStyle(fontSize: 14, color: Colors.grey.shade700),
                  ),
                  if (type == "pending") ...[
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => cancelRequest(request),
                            icon: const Icon(Icons.cancel, size: 18),
                            label: const Text("Cancel Request"),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.red,
                              side: const BorderSide(color: Colors.red),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}