import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'teacher_profile_page.dart';
import 'teacher_timetables_page.dart';
import 'teacher_temp_timetable_page.dart';

class TeacherHomePage extends StatefulWidget {
  const TeacherHomePage({super.key});

  @override
  State<TeacherHomePage> createState() => _TeacherHomePageState();
}

class _TeacherHomePageState extends State<TeacherHomePage> {
  final user = FirebaseAuth.instance.currentUser;
  final dbRef = FirebaseDatabase.instance.ref();
  bool isLoading = false;
  Map<String, dynamic>? teacherData;
  List<Map<String, dynamic>> pendingRequests = [];
  List<Map<String, dynamic>> acceptedRequests = [];
  List<Map<String, dynamic>> rejectedRequests = [];
  int selectedTab = 0;

  @override
  void initState() {
    super.initState();
    loadTeacherData();
    loadAllRequests();
    if (user != null) {
      dbRef
          .child("teacher_requests")
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
        "studentName": requestData['studentName'] ?? "Student",
        "studentEmail": requestData['studentEmail'] ?? "",
        "studentId": requestData['studentId'] ?? "",
        "day": requestData['day'] ?? "",
        "timeSlot": requestData['timeSlot'] ?? "",
        "period": requestData['period'] ?? "",
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

  Future<void> loadTeacherData() async {
    if (user == null) return;
    try {
      final snapshot = await dbRef.child("users/${user!.uid}").get();
      if (snapshot.exists && mounted) {
        final data = Map<String, dynamic>.from(snapshot.value as Map);
        if (data['isActive'] == false) {
          await FirebaseAuth.instance.signOut();
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text("Your account has been deleted"),
                backgroundColor: Colors.red,
              ),
            );
            Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false);
          }
          return;
        }
        setState(() {
          teacherData = data;
        });
      }
    } catch (e) {
      debugPrint("Error loading teacher data: $e");
    }
  }

  Future<void> loadAllRequests() async {
    if (user == null) return;
    try {
      final snapshot = await dbRef
          .child("teacher_requests")
          .child(user!.uid)
          .get();
      if (snapshot.exists && mounted) {
        _processRequests(snapshot.value as Map);
      }
    } catch (e) {
      debugPrint("Error loading requests: $e");
    }
  }

  Future<void> updateRequestStatus(String requestId, String status, String studentId) async {
    try {
      await dbRef
          .child("teacher_requests")
          .child(user!.uid)
          .child(requestId)
          .update({
            "status": status,
            "updatedAt": DateTime.now().toIso8601String(),
          });
      await dbRef
          .child("student_requests")
          .child(studentId)
          .child(requestId)
          .update({
            "status": status,
            "updatedAt": DateTime.now().toIso8601String(),
          });
      await dbRef
          .child("appointment_requests")
          .child(requestId)
          .update({
            "status": status,
            "updatedAt": DateTime.now().toIso8601String(),
          });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Request $status"),
            backgroundColor: status == "accepted" ? Colors.green : Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: ${e.toString()}"), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _showTimetableOptions() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Timetable Options',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const Divider(),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.calendar_today, color: Colors.blue),
              ),
              title: const Text(
                'Permanent Timetable',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: const Text('Set your regular weekly schedule'),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const TeacherTimetablesPage()),
                );
              },
            ),
            const Divider(),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.timer, color: Colors.orange),
              ),
              title: const Text(
                'Temporary Timetable',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: const Text('For extra lectures or changes (valid for today)'),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const TeacherTempTimetablePage()),
                );
              },
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Future<void> deleteAccount() async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Delete Account"),
        content: const Text(
          "Are you sure you want to delete your account? This action cannot be undone.\n\nYour profile will no longer be visible to students, and you will be logged out.",
          style: TextStyle(fontSize: 14),
        ),
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
              try {
                await dbRef.child("users/${user!.uid}").update({
                  'isActive': false,
                  'deletedAt': DateTime.now().toIso8601String(),
                  'deletedBy': user!.uid,
                });
                await FirebaseAuth.instance.signOut();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text("Account deleted successfully"),
                      backgroundColor: Colors.green,
                    ),
                  );
                  Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false);
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text("Error deleting account: ${e.toString()}"),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
                setState(() => isLoading = false);
              }
            },
            child: const Text("Delete", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
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
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        title: const Text(
          "Teacher Dashboard",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Container(
            color: Colors.white,
            child: Row(
              children: [
                _buildTabButton("Pending (${pendingRequests.length})", 0),
                _buildTabButton("Accepted (${acceptedRequests.length})", 1),
                _buildTabButton("Rejected (${rejectedRequests.length})", 2),
              ],
            ),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_today),
            onPressed: _showTimetableOptions,
            tooltip: 'Timetable Options',
          ),
          IconButton(
            icon: const Icon(Icons.person),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const TeacherProfilePage()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.red),
            onPressed: deleteAccount,
            tooltip: 'Delete Account',
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
              ? _buildRequestsTab(pendingRequests, "pending")
              : selectedTab == 1
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
                color: isSelected ? Colors.green.shade700 : Colors.transparent,
                width: 2,
              ),
            ),
          ),
          child: Center(
            child: Text(
              title,
              style: TextStyle(
                color: isSelected ? Colors.green.shade700 : Colors.grey.shade600,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                fontSize: 12,
              ),
            ),
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
                "Students can request appointments when you're available",
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
                              request['studentName'],
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
                          child: ElevatedButton(
                            onPressed: () => updateRequestStatus(
                              request['requestId'], 
                              "accepted",
                              request['studentId']
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            child: const Text("Accept"),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () => updateRequestStatus(
                              request['requestId'], 
                              "rejected",
                              request['studentId']
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            child: const Text("Reject"),
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