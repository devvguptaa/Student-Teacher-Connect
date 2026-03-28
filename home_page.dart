import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'teacher_detail_page.dart';
import 'student_profile_page.dart';

class HomePage extends StatefulWidget {
  final String role;

  const HomePage({super.key, required this.role});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final dbRef = FirebaseDatabase.instance.ref();
  final user = FirebaseAuth.instance.currentUser;

  List<Map<String, dynamic>> teachers = [];
  List<Map<String, dynamic>> pendingRequests = [];
  String searchQuery = "";
  bool isLoading = true;
  String? errorMessage;

  @override
  void initState() {
    super.initState();
    loadTeachers();
  }

  Future<void> loadTeachers() async {
    if (!mounted) return;
    setState(() {
      isLoading = true;
      errorMessage = null;
    });
    try {
      final snapshot = await dbRef.child("users").get();
      if (snapshot.exists) {
        Map data = snapshot.value as Map;
        List<Map<String, dynamic>> temp = [];
        data.forEach((key, value) {
          final userData = Map<String, dynamic>.from(value);
          if (userData['role'] == "teacher") {
            temp.add({
              "uid": key,
              "name": userData['name'] ?? "Unknown",
              "subject": userData['subject'] ?? "General",
              "email": userData['email'] ?? "",
            });
          }
        });
        if (mounted) setState(() => teachers = temp);
      } else {
        if (mounted) setState(() => teachers = []);
      }
    } catch (e) {
      if (mounted) {
        setState(() => errorMessage = "Failed to load teachers: ${e.toString()}");
      }
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
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
        title: const Text("Find Teachers", style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.person),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const StudentProfilePage()),
              );
            },
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : errorMessage != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.error_outline, size: 64, color: Colors.red),
                      const SizedBox(height: 16),
                      Text(errorMessage!),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: loadTeachers,
                        child: const Text("Retry"),
                      ),
                    ],
                  ),
                )
              : SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        TextField(
                          onChanged: (v) => setState(() => searchQuery = v),
                          decoration: InputDecoration(
                            hintText: "Search teachers...",
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
                                      leading: CircleAvatar(
                                        backgroundColor: Colors.blue.shade100,
                                        child: Icon(
                                          Icons.person,
                                          color: Colors.blue.shade700,
                                        ),
                                      ),
                                      title: Text(
                                        teacher['name'],
                                        style: const TextStyle(fontWeight: FontWeight.bold),
                                      ),
                                      subtitle: Text(teacher['subject']),
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
}