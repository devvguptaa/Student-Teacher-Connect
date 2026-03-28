import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';

class StudentSignupPage extends StatefulWidget {
  const StudentSignupPage({super.key});

  @override
  State<StudentSignupPage> createState() => _StudentSignupPageState();
}

class _StudentSignupPageState extends State<StudentSignupPage> {
  bool isLoading = false;
  bool obscurePassword = true;
  bool obscureConfirmPassword = true;

  final TextEditingController nameController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController confirmPasswordController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();
  final TextEditingController rollNoController = TextEditingController();
  final TextEditingController branchController = TextEditingController();
  final TextEditingController divisionController = TextEditingController();
  final TextEditingController yearController = TextEditingController();
  final TextEditingController bioController = TextEditingController();

  @override
  void dispose() {
    nameController.dispose();
    emailController.dispose();
    passwordController.dispose();
    confirmPasswordController.dispose();
    phoneController.dispose();
    rollNoController.dispose();
    branchController.dispose();
    divisionController.dispose();
    yearController.dispose();
    bioController.dispose();
    super.dispose();
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  Future<void> signUp() async {
    if (nameController.text.trim().isEmpty) {
      _showSnackBar("Please enter your full name", Colors.red);
      return;
    }
    
    if (emailController.text.trim().isEmpty) {
      _showSnackBar("Please enter your email", Colors.red);
      return;
    }
    
    if (!emailController.text.contains('@')) {
      _showSnackBar("Please enter a valid email address", Colors.red);
      return;
    }
    
    if (passwordController.text.isEmpty) {
      _showSnackBar("Please enter a password", Colors.red);
      return;
    }
    
    if (passwordController.text != confirmPasswordController.text) {
      _showSnackBar("Passwords don't match", Colors.red);
      return;
    }
    
    if (passwordController.text.length < 6) {
      _showSnackBar("Password must be at least 6 characters", Colors.red);
      return;
    }
    
    if (branchController.text.trim().isEmpty) {
      _showSnackBar("Please enter your branch", Colors.red);
      return;
    }

    setState(() => isLoading = true);

    try {
      UserCredential userCredential = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(
            email: emailController.text.trim(),
            password: passwordController.text,
          );

      String uid = userCredential.user!.uid;

      Map<String, dynamic> userData = {
        'uid': uid,
        'name': nameController.text.trim(),
        'email': emailController.text.trim(),
        'role': 'student',
        'phone': phoneController.text.trim(),
        'rollNo': rollNoController.text.trim(),
        'branch': branchController.text.trim(),
        'division': divisionController.text.trim(),
        'year': yearController.text.trim(),
        'bio': bioController.text.trim(),
        'createdAt': DateTime.now().toIso8601String(),
        'updatedAt': DateTime.now().toIso8601String(),
        'profileImageUrl': null,
        'totalRequests': 0,
        'approvedRequests': 0,
        'isActive': true,
      };

      final dbRef = FirebaseDatabase.instance.ref();
      await dbRef.child("users").child(uid).set(userData);

      if (mounted) {
        _showSnackBar("Student account created successfully! 🎓", Colors.green);
        Navigator.pushReplacementNamed(context, '/student-dashboard');
      }
    } on FirebaseAuthException catch (e) {
      String message = '';
      if (e.code == 'email-already-in-use') {
        message = 'This email is already registered. Please login instead.';
      } else if (e.code == 'weak-password') {
        message = 'Password is too weak. Use at least 6 characters.';
      } else if (e.code == 'invalid-email') {
        message = 'Invalid email address format';
      } else {
        message = 'Signup failed: ${e.message}';
      }
      
      if (mounted) _showSnackBar(message, Colors.red);
    } catch (e) {
      if (mounted) _showSnackBar('Error: ${e.toString()}', Colors.red);
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.blue.shade50, Colors.white],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 20),
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.blue.shade700, Colors.blue.shade400],
                      ),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.school, size: 40, color: Colors.white),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Student Sign Up',
                    style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Create your student account',
                    style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
                  ),
                  const SizedBox(height: 30),

                  const Text(
                    'Personal Information',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 15),
                  _buildTextField("Full Name *", Icons.person, nameController),
                  const SizedBox(height: 15),
                  _buildTextField("Email Address *", Icons.email, emailController, keyboardType: TextInputType.emailAddress),
                  const SizedBox(height: 15),
                  _buildTextField("Phone Number", Icons.phone, phoneController, keyboardType: TextInputType.phone),
                  const SizedBox(height: 15),
                  _buildTextField("Roll Number", Icons.numbers, rollNoController),
                  const SizedBox(height: 15),
                  _buildTextField("Branch *", Icons.business, branchController),
                  const SizedBox(height: 15),
                  _buildTextField("Division", Icons.group, divisionController),
                  const SizedBox(height: 15),
                  _buildTextField("Year", Icons.calendar_today, yearController, keyboardType: TextInputType.number),
                  const SizedBox(height: 15),
                  _buildTextField("Bio", Icons.info, bioController, maxLines: 3),
                  
                  const SizedBox(height: 20),
                  const Text(
                    'Account Security',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 15),
                  _buildPasswordField("Password *", Icons.lock, passwordController, obscurePassword, () {
                    setState(() => obscurePassword = !obscurePassword);
                  }),
                  const SizedBox(height: 15),
                  _buildPasswordField("Confirm Password *", Icons.lock_outline, confirmPasswordController, obscureConfirmPassword, () {
                    setState(() => obscureConfirmPassword = !obscureConfirmPassword);
                  }),

                  const SizedBox(height: 30),
                  ElevatedButton(
                    onPressed: isLoading ? null : signUp,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: isLoading
                        ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Text('Create Student Account', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text("Already have an account? ", style: TextStyle(color: Colors.grey.shade600)),
                      TextButton(
                        onPressed: () => Navigator.pushReplacementNamed(context, '/login', arguments: 'student'),
                        child: const Text('Sign In', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(String label, IconData icon, TextEditingController controller, {TextInputType? keyboardType, int maxLines = 1}) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        hintText: label.contains('*') ? 'Required' : 'Optional',
        prefixIcon: Icon(icon, color: Colors.blue.shade700),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Widget _buildPasswordField(String label, IconData icon, TextEditingController controller, bool obscure, VoidCallback toggle) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      decoration: InputDecoration(
        labelText: label,
        hintText: 'Required',
        prefixIcon: Icon(icon, color: Colors.blue.shade700),
        suffixIcon: IconButton(
          icon: Icon(obscure ? Icons.visibility_off : Icons.visibility, color: Colors.grey),
          onPressed: toggle,
        ),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}