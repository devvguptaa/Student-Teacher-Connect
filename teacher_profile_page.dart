import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';

class TeacherProfilePage extends StatefulWidget {
  const TeacherProfilePage({super.key});

  @override
  State<TeacherProfilePage> createState() => _TeacherProfilePageState();
}

class _TeacherProfilePageState extends State<TeacherProfilePage> {
  final user = FirebaseAuth.instance.currentUser;
  final dbRef = FirebaseDatabase.instance.ref();
  final storageRef = FirebaseStorage.instance.ref();
  Map<String, dynamic>? teacherData;
  bool isLoading = true;
  bool isEditing = false;
  bool isUploadingImage = false;
  final TextEditingController nameController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();
  final TextEditingController roomNoController = TextEditingController();
  final TextEditingController branchController = TextEditingController();
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
    roomNoController.dispose();
    branchController.dispose();
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
          teacherData = Map<String, dynamic>.from(snapshot.value as Map);
          nameController.text = teacherData!['name'] ?? '';
          phoneController.text = teacherData!['phone'] ?? '';
          roomNoController.text = teacherData!['roomNo'] ?? '';
          branchController.text = teacherData!['branch'] ?? '';
          bioController.text = teacherData!['bio'] ?? '';
          profileImageUrl = teacherData!['profileImageUrl'];
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
              leading: const Icon(Icons.photo_library, color: Colors.green),
              title: const Text('Choose from Gallery'),
              onTap: () {
                Navigator.pop(context);
                pickImage();
              },
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt, color: Colors.green),
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

  Future<void> updateProfile() async {
    if (user == null) return;
    if (mounted) setState(() => isLoading = true);
    try {
      String? imageUrl = profileImageUrl;
      if (selectedImageFile != null) {
        String? uploadedUrl = await uploadImageToStorage(selectedImageFile!);
        if (uploadedUrl != null) imageUrl = uploadedUrl;
      }
      Map<String, dynamic> updates = {
        'name': nameController.text.trim(),
        'phone': phoneController.text.trim(),
        'roomNo': roomNoController.text.trim(),
        'branch': branchController.text.trim(),
        'bio': bioController.text.trim(),
        'updatedAt': DateTime.now().toIso8601String(),
      };
      if (imageUrl != null) {
        updates['profileImageUrl'] = imageUrl;
      } else if (selectedImageFile == null && profileImageUrl == null) {
        updates['profileImageUrl'] = null;
      }
      await dbRef.child("users/${user!.uid}").update(updates);
      if (mounted) {
        setState(() {
          teacherData!.addAll(updates);
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

  Widget _buildProfileImage() {
    if (isUploadingImage) {
      return Container(
        width: 120,
        height: 120,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.grey,
        ),
        child: const Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Colors.green),
          ),
        ),
      );
    }
    if (selectedImageFile != null) {
      return ClipOval(
        child: Image.file(
          selectedImageFile!,
          width: 120,
          height: 120,
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
          width: 120,
          height: 120,
          fit: BoxFit.cover,
          placeholder: (context, url) => Container(
            color: Colors.grey.shade200,
            child: const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.green),
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
    return CircleAvatar(
      radius: 60,
      backgroundColor: Colors.green.shade100,
      child: Icon(Icons.person, size: 60, color: Colors.green.shade700),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (teacherData == null && !isLoading) {
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
        ],
      ),
      body: isLoading
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.green),
                  ),
                  SizedBox(height: 16),
                  Text("Loading profile...", style: TextStyle(color: Colors.grey)),
                ],
              ),
            )
          : SingleChildScrollView(
              child: Column(
                children: [
                  const SizedBox(height: 20),
                  Center(
                    child: Stack(
                      children: [
                        _buildProfileImage(),
                        if (isEditing)
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: GestureDetector(
                              onTap: showImagePickerOptions,
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.green,
                                  shape: BoxShape.circle,
                                  border: Border.all(color: Colors.white, width: 3),
                                ),
                                child: const Icon(Icons.camera_alt, color: Colors.white, size: 20),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Card(
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
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
                                  _buildReadOnlyField("Email", Icons.email, teacherData!['email'] ?? ''),
                                  const SizedBox(height: 15),
                                  _buildEditableField("Phone Number", Icons.phone, phoneController, keyboardType: TextInputType.phone),
                                  const SizedBox(height: 15),
                                  _buildEditableField("Room Number", Icons.meeting_room, roomNoController),
                                  const SizedBox(height: 15),
                                  _buildEditableField("Branch/Department", Icons.business, branchController),
                                  const SizedBox(height: 15),
                                  _buildEditableField("Bio", Icons.info, bioController, maxLines: 3),
                                  const SizedBox(height: 20),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: ElevatedButton(
                                          onPressed: updateProfile,
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.green,
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
                                            nameController.text = teacherData!['name'] ?? '';
                                            phoneController.text = teacherData!['phone'] ?? '';
                                            roomNoController.text = teacherData!['roomNo'] ?? '';
                                            branchController.text = teacherData!['branch'] ?? '';
                                            bioController.text = teacherData!['bio'] ?? '';
                                            profileImageUrl = teacherData!['profileImageUrl'];
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
                                          teacherData!['name'] ?? 'Teacher',
                                          style: const TextStyle(
                                            fontSize: 24,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        const SizedBox(height: 5),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: Colors.green.shade50,
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          child: Text(
                                            teacherData!['role'] ?? 'Teacher',
                                            style: TextStyle(
                                              color: Colors.green.shade700,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const Divider(height: 40),
                                  _buildInfoTile(Icons.email, "Email", teacherData!['email'] ?? 'Not provided'),
                                  _buildInfoTile(Icons.phone, "Phone", teacherData!['phone'] ?? 'Not provided'),
                                  _buildInfoTile(Icons.meeting_room, "Room Number", teacherData!['roomNo'] ?? 'Not provided'),
                                  _buildInfoTile(Icons.business, "Branch/Department", teacherData!['branch'] ?? 'Not provided'),
                                  if (teacherData!['bio'] != null && teacherData!['bio'] != '')
                                    _buildInfoTile(Icons.info, "Bio", teacherData!['bio']),
                                  const SizedBox(height: 20),
                                  Container(
                                    padding: const EdgeInsets.all(15),
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: [Colors.green.shade50, Colors.green.shade100],
                                      ),
                                      borderRadius: BorderRadius.circular(15),
                                    ),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                                      children: [
                                        _buildStatItem("Students", teacherData!['totalStudents']?.toString() ?? '0', Icons.people),
                                        Container(height: 40, width: 1, color: Colors.grey.shade300),
                                        _buildStatItem("Requests", teacherData!['totalRequests']?.toString() ?? '0', Icons.pending_actions),
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
            prefixIcon: Icon(icon, color: Colors.green.shade700),
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
              color: Colors.green.shade50,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: Colors.green.shade700, size: 20),
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
        Icon(icon, color: Colors.green.shade700, size: 24),
        const SizedBox(height: 8),
        Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.green.shade900)),
        Text(label, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
      ],
    );
  }
}