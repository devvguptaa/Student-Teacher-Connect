import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';

class StudentProfilePage extends StatefulWidget {
  const StudentProfilePage({super.key});

  @override
  State<StudentProfilePage> createState() => _StudentProfilePageState();
}

class _StudentProfilePageState extends State<StudentProfilePage> {
  final user = FirebaseAuth.instance.currentUser;
  final dbRef = FirebaseDatabase.instance.ref();
  final storageRef = FirebaseStorage.instance.ref();
  Map<String, dynamic>? userData;
  bool isLoading = true;
  bool isEditing = false;
  bool isUploadingImage = false;
  final TextEditingController nameController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();
  final TextEditingController rollNoController = TextEditingController();
  final TextEditingController branchController = TextEditingController();
  final TextEditingController divisionController = TextEditingController();
  final TextEditingController yearController = TextEditingController();
  final TextEditingController bioController = TextEditingController();
  String? profileImageUrl;
  File? selectedImageFile;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    loadProfile();
  }

  @override
  void dispose() {
    nameController.dispose();
    phoneController.dispose();
    rollNoController.dispose();
    branchController.dispose();
    divisionController.dispose();
    yearController.dispose();
    bioController.dispose();
    super.dispose();
  }

  Future<void> loadProfile() async {
    if (user == null) return;
    if (!mounted) return;
    setState(() => isLoading = true);
    try {
      final snapshot = await dbRef.child("users/${user!.uid}").get();
      if (snapshot.exists && mounted) {
        setState(() {
          userData = Map<String, dynamic>.from(snapshot.value as Map);
          nameController.text = userData!['name'] ?? '';
          phoneController.text = userData!['phone'] ?? '';
          rollNoController.text = userData!['rollNo'] ?? '';
          branchController.text = userData!['branch'] ?? '';
          divisionController.text = userData!['division'] ?? '';
          yearController.text = userData!['year'] ?? '';
          bioController.text = userData!['bio'] ?? '';
          profileImageUrl = userData!['profileImageUrl'];
        });
      }
    } catch (e) {
      debugPrint("Error loading profile: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Error loading profile: ${e.toString()}"),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  Future<String?> uploadImageToStorage(File imageFile) async {
    if (user == null) return null;
    try {
      if (mounted) setState(() => isUploadingImage = true);
      String fileName = 'profile_${user!.uid}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      Reference imageRef = storageRef.child('profile_images/$fileName');
      final metadata = SettableMetadata(
        contentType: 'image/jpeg',
        customMetadata: {
          'uid': user!.uid,
          'uploadedAt': DateTime.now().toIso8601String(),
        },
      );
      await imageRef.putFile(imageFile, metadata);
      String downloadUrl = await imageRef.getDownloadURL();
      return downloadUrl;
    } catch (e) {
      debugPrint("Error uploading image: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Error uploading image: ${e.toString()}"),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return null;
    } finally {
      if (mounted) setState(() => isUploadingImage = false);
    }
  }

  Future<void> pickImage() async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 85,
      );
      if (pickedFile != null) {
        if (mounted) {
          setState(() {
            selectedImageFile = File(pickedFile.path);
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Image selected. Save profile to upload."),
              duration: Duration(seconds: 2),
              backgroundColor: Colors.blue,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    } catch (e) {
      debugPrint("Error picking image: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Error picking image: ${e.toString()}"),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> takePhoto() async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 85,
      );
      if (pickedFile != null) {
        if (mounted) {
          setState(() {
            selectedImageFile = File(pickedFile.path);
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Photo captured. Save profile to upload."),
              duration: Duration(seconds: 2),
              backgroundColor: Colors.blue,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    } catch (e) {
      debugPrint("Error taking photo: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Error taking photo: ${e.toString()}"),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void showImagePickerOptions() {
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
                'Choose Profile Picture',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.photo_library, color: Colors.blue),
              title: const Text('Choose from Gallery'),
              onTap: () {
                Navigator.pop(context);
                pickImage();
              },
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt, color: Colors.blue),
              title: const Text('Take a Photo'),
              onTap: () {
                Navigator.pop(context);
                takePhoto();
              },
            ),
            if (profileImageUrl != null || selectedImageFile != null)
              ListTile(
                leading: const Icon(Icons.delete, color: Colors.red),
                title: const Text('Remove Photo'),
                onTap: () {
                  Navigator.pop(context);
                  setState(() {
                    selectedImageFile = null;
                    profileImageUrl = null;
                  });
                },
              ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Future<void> _updateNameInAllRequests(String oldName, String newName) async {
    if (user == null) return;
    try {
      final requestsSnapshot = await dbRef
          .child("student_requests")
          .child(user!.uid)
          .get();
      if (requestsSnapshot.exists) {
        final Map<dynamic, dynamic> requests = requestsSnapshot.value as Map;
        for (var requestId in requests.keys) {
          final requestData = Map<String, dynamic>.from(requests[requestId]);
          await dbRef
              .child("student_requests")
              .child(user!.uid)
              .child(requestId)
              .update({"studentName": newName});
          final teacherId = requestData['teacherId'];
          if (teacherId != null) {
            await dbRef
                .child("teacher_requests")
                .child(teacherId)
                .child(requestId)
                .update({"studentName": newName});
          }
          await dbRef
              .child("appointment_requests")
              .child(requestId)
              .update({"studentName": newName});
        }
      }
    } catch (e) {
      debugPrint("Error updating name in requests: $e");
    }
  }

  Future<void> updateProfile() async {
    if (user == null) return;
    if (mounted) setState(() => isLoading = true);
    try {
      String? imageUrl = profileImageUrl;
      if (selectedImageFile != null) {
        String? uploadedUrl = await uploadImageToStorage(selectedImageFile!);
        if (uploadedUrl != null) imageUrl = uploadedUrl;
      }
      String oldName = userData?['name'] ?? '';
      String newName = nameController.text.trim();
      Map<String, dynamic> updates = {
        'name': newName,
        'phone': phoneController.text.trim(),
        'rollNo': rollNoController.text.trim(),
        'branch': branchController.text.trim(),
        'division': divisionController.text.trim(),
        'year': yearController.text.trim(),
        'bio': bioController.text.trim(),
        'updatedAt': DateTime.now().toIso8601String(),
      };
      if (imageUrl != null) {
        updates['profileImageUrl'] = imageUrl;
      } else if (selectedImageFile == null && profileImageUrl == null) {
        updates['profileImageUrl'] = null;
      }
      await dbRef.child("users/${user!.uid}").update(updates);
      if (oldName != newName && newName.isNotEmpty) {
        await _updateNameInAllRequests(oldName, newName);
      }
      if (mounted) {
        setState(() {
          userData!.addAll(updates);
          profileImageUrl = imageUrl;
          selectedImageFile = null;
          isEditing = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Profile updated successfully!"),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Error updating profile: ${e.toString()}"),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  Future<void> logout() async {
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
              await FirebaseAuth.instance.signOut();
              if (mounted) {
                Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false);
              }
            },
            child: const Text("Logout", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileImage() {
    if (isUploadingImage) {
      return Container(
        width: 140,
        height: 140,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.grey,
        ),
        child: const Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
          ),
        ),
      );
    }
    if (selectedImageFile != null) {
      return ClipOval(
        child: Image.file(
          selectedImageFile!,
          width: 140,
          height: 140,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.grey.shade200,
              ),
              child: const Icon(Icons.error, color: Colors.red),
            );
          },
        ),
      );
    }
    if (profileImageUrl != null && profileImageUrl!.isNotEmpty) {
      return ClipOval(
        child: CachedNetworkImage(
          imageUrl: profileImageUrl!,
          width: 140,
          height: 140,
          fit: BoxFit.cover,
          placeholder: (context, url) => Container(
            color: Colors.grey.shade200,
            child: const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
              ),
            ),
          ),
          errorWidget: (context, url, error) => Container(
            color: Colors.grey.shade200,
            child: const Icon(Icons.error, color: Colors.grey),
          ),
        ),
      );
    }
    return Container(
      width: 140,
      height: 140,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [Colors.blue.shade400, Colors.blue.shade700],
        ),
      ),
      child: const Center(
        child: Icon(Icons.person, size: 70, color: Colors.white),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (userData == null && !isLoading) {
      return Scaffold(
        appBar: AppBar(
          elevation: 0,
          backgroundColor: Colors.white,
          title: const Text(
            "My Profile",
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
        body: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 64, color: Colors.grey),
              SizedBox(height: 16),
              Text("No user data found", style: TextStyle(fontSize: 16, color: Colors.grey)),
            ],
          ),
        ),
      );
    }
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        title: const Text(
          "My Profile",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          if (!isEditing && !isLoading)
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () => setState(() => isEditing = true),
            ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: logout,
          ),
        ],
      ),
      body: isLoading
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
                  ),
                  SizedBox(height: 16),
                  Text("Loading profile...", style: TextStyle(color: Colors.grey)),
                ],
              ),
            )
          : SingleChildScrollView(
              child: Column(
                children: [
                  Stack(
                    children: [
                      Container(
                        height: 150,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Colors.blue.shade700, Colors.blue.shade400],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: const BorderRadius.only(
                            bottomLeft: Radius.circular(30),
                            bottomRight: Radius.circular(30),
                          ),
                        ),
                      ),
                      Positioned(
                        bottom: -50,
                        left: 0,
                        right: 0,
                        child: Center(
                          child: GestureDetector(
                            onTap: isEditing ? showImagePickerOptions : null,
                            child: Container(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.2),
                                    blurRadius: 10,
                                    offset: const Offset(0, 5),
                                  ),
                                ],
                              ),
                              child: Stack(
                                children: [
                                  _buildProfileImage(),
                                  if (isEditing)
                                    Positioned(
                                      bottom: 0,
                                      right: 0,
                                      child: Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: Colors.blue,
                                          shape: BoxShape.circle,
                                          border: Border.all(color: Colors.white, width: 3),
                                        ),
                                        child: const Icon(
                                          Icons.camera_alt,
                                          color: Colors.white,
                                          size: 20,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 70),
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Card(
                      elevation: 2,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: isEditing
                              ? [
                                  const Text(
                                    "Edit Profile",
                                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                                  ),
                                  const SizedBox(height: 20),
                                  _buildEditableField("Full Name", Icons.person, nameController),
                                  const SizedBox(height: 15),
                                  _buildReadOnlyField("Email", Icons.email, userData!['email'] ?? ''),
                                  const SizedBox(height: 15),
                                  _buildEditableField("Phone Number", Icons.phone, phoneController, keyboardType: TextInputType.phone),
                                  const SizedBox(height: 15),
                                  _buildEditableField("Roll Number", Icons.numbers, rollNoController),
                                  const SizedBox(height: 15),
                                  _buildEditableField("Branch", Icons.business, branchController),
                                  const SizedBox(height: 15),
                                  _buildEditableField("Division", Icons.group, divisionController),
                                  const SizedBox(height: 15),
                                  _buildEditableField("Year", Icons.calendar_today, yearController, keyboardType: TextInputType.number),
                                  const SizedBox(height: 15),
                                  _buildEditableField("Bio", Icons.info, bioController, maxLines: 3),
                                  const SizedBox(height: 20),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: ElevatedButton(
                                          onPressed: updateProfile,
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.blue,
                                            padding: const EdgeInsets.symmetric(vertical: 12),
                                            shape: RoundedRectangleBorder(
                                              borderRadius: BorderRadius.circular(12),
                                            ),
                                          ),
                                          child: const Text("Save Changes"),
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: OutlinedButton(
                                          onPressed: () {
                                            setState(() {
                                              isEditing = false;
                                              selectedImageFile = null;
                                            });
                                            nameController.text = userData!['name'] ?? '';
                                            phoneController.text = userData!['phone'] ?? '';
                                            rollNoController.text = userData!['rollNo'] ?? '';
                                            branchController.text = userData!['branch'] ?? '';
                                            divisionController.text = userData!['division'] ?? '';
                                            yearController.text = userData!['year'] ?? '';
                                            bioController.text = userData!['bio'] ?? '';
                                            profileImageUrl = userData!['profileImageUrl'];
                                          },
                                          child: const Text("Cancel"),
                                        ),
                                      ),
                                    ],
                                  ),
                                ]
                              : [
                                  Center(
                                    child: Column(
                                      children: [
                                        Text(
                                          userData!['name'] ?? 'Student',
                                          style: const TextStyle(
                                            fontSize: 24,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        const SizedBox(height: 5),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: Colors.blue.shade50,
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          child: Text(
                                            userData!['role'] ?? 'Student',
                                            style: TextStyle(
                                              color: Colors.blue.shade700,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const Divider(height: 40),
                                  _buildInfoTile(Icons.email, "Email", userData!['email'] ?? 'Not provided'),
                                  _buildInfoTile(Icons.phone, "Phone", userData!['phone'] ?? 'Not provided'),
                                  _buildInfoTile(Icons.numbers, "Roll Number", userData!['rollNo'] ?? 'Not provided'),
                                  _buildInfoTile(Icons.business, "Branch", userData!['branch'] ?? 'Not provided'),
                                  _buildInfoTile(Icons.group, "Division", userData!['division'] ?? 'Not provided'),
                                  _buildInfoTile(Icons.calendar_today, "Year", userData!['year'] ?? 'Not provided'),
                                  if (userData!['bio'] != null && userData!['bio'] != '')
                                    _buildInfoTile(Icons.info, "Bio", userData!['bio']),
                                  _buildInfoTile(
                                    Icons.calendar_today,
                                    "Member Since",
                                    userData!['createdAt'] != null
                                        ? _formatDate(userData!['createdAt'])
                                        : 'Recently',
                                  ),
                                  const SizedBox(height: 20),
                                  Container(
                                    padding: const EdgeInsets.all(15),
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: [Colors.blue.shade50, Colors.blue.shade100],
                                      ),
                                      borderRadius: BorderRadius.circular(15),
                                    ),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                                      children: [
                                        _buildStatItem(
                                          "Requests",
                                          userData!['totalRequests']?.toString() ?? '0',
                                          Icons.pending_actions,
                                        ),
                                        Container(
                                          height: 40,
                                          width: 1,
                                          color: Colors.grey.shade300,
                                        ),
                                        _buildStatItem(
                                          "Approved",
                                          userData!['approvedRequests']?.toString() ?? '0',
                                          Icons.check_circle,
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildEditableField(String label, IconData icon, TextEditingController controller,
      {TextInputType? keyboardType, int maxLines = 1}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.grey.shade700)),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          maxLines: maxLines,
          decoration: InputDecoration(
            prefixIcon: Icon(icon, color: Colors.blue.shade700),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
          ),
        ),
      ],
    );
  }

  Widget _buildReadOnlyField(String label, IconData icon, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.grey.shade700)),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: Row(
            children: [
              Icon(icon, size: 20, color: Colors.grey.shade600),
              const SizedBox(width: 10),
              Text(value, style: TextStyle(color: Colors.grey.shade700)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildInfoTile(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: Colors.blue.shade700, size: 20),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                const SizedBox(height: 4),
                Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: Colors.blue.shade700, size: 24),
        const SizedBox(height: 8),
        Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.blue.shade900)),
        Text(label, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
      ],
    );
  }

  String _formatDate(String dateString) {
    try {
      DateTime date = DateTime.parse(dateString);
      return "${date.day}/${date.month}/${date.year}";
    } catch (e) {
      return dateString;
    }
  }
}