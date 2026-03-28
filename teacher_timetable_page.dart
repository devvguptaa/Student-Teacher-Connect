import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';

class TeacherDetailPage extends StatefulWidget {
  final Map<String, dynamic> teacher;

  const TeacherDetailPage({super.key, required this.teacher});

  @override
  State<TeacherDetailPage> createState() => _TeacherDetailPageState();
}

class _TeacherDetailPageState extends State<TeacherDetailPage> {
  final dbRef = FirebaseDatabase.instance.ref();
  Map<String, dynamic>? timetableData;
  bool isLoading = true;
  String? selectedSlot;
  String? purpose;
  
  final List<TimeSlotDisplay> timeSlots = [
    TimeSlotDisplay("08:10 - 09:05", "Period 1"),
    TimeSlotDisplay("09:05 - 10:00", "Period 2"),
    TimeSlotDisplay("10:20 - 11:15", "Period 3"),
    TimeSlotDisplay("11:15 - 12:10", "Period 4"),
    TimeSlotDisplay("12:50 - 13:45", "Period 5"),
    TimeSlotDisplay("13:45 - 14:40", "Period 6"),
    TimeSlotDisplay("14:40 - 15:35", "Period 7"),
    TimeSlotDisplay("15:35 - 16:30", "Period 8"),
  ];

  @override
  void initState() {
    super.initState();
    loadTimetable();
    
    // Listen for real-time updates
    dbRef
        .child("teacher_timetables")
        .child(widget.teacher['uid'])
        .onValue
        .listen((event) {
      if (event.snapshot.exists && mounted) {
        setState(() {
          timetableData = Map<String, dynamic>.from(event.snapshot.value as Map);
        });
      }
    });
  }

  Future<void> loadTimetable() async {
    try {
      final snapshot = await dbRef
          .child("teacher_timetables")
          .child(widget.teacher['uid'])
          .get();
      
      if (snapshot.exists && mounted) {
        setState(() {
          timetableData = Map<String, dynamic>.from(snapshot.value as Map);
        });
      }
    } catch (e) {
      debugPrint("Error loading timetable: $e");
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  String getStatusForSlot(int index) {
    if (timetableData == null) return "available";
    String slotKey = "slot_${index + 1}";
    return timetableData![slotKey]?['status'] ?? "available";
  }

  String getStatusText(String status) {
    switch (status) {
      case "available":
        return "Available";
      case "not_available":
        return "Not Available";
      case "other_class":
        return "In Other Class";
      default:
        return "Available";
    }
  }

  Color getStatusColor(String status) {
    switch (status) {
      case "available":
        return Colors.green;
      case "not_available":
        return Colors.red;
      case "other_class":
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  IconData getStatusIcon(String status) {
    switch (status) {
      case "available":
        return Icons.check_circle;
      case "not_available":
        return Icons.cancel;
      case "other_class":
        return Icons.class_;
      default:
        return Icons.help;
    }
  }

  void showRequestDialog(int index, TimeSlotDisplay slot) {
    String status = getStatusForSlot(index);
    
    if (status != "available") {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Teacher is ${getStatusText(status).toLowerCase()} during this time slot"),
          backgroundColor: getStatusColor(status),
        ),
      );
      return;
    }
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Request Appointment"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Teacher: ${widget.teacher['name']}"),
            const SizedBox(height: 8),
            Text("Time Slot: ${slot.time}"),
            const SizedBox(height: 8),
            Text("Period: ${slot.period}"),
            const SizedBox(height: 16),
            TextField(
              onChanged: (value) => purpose = value,
              maxLines: 3,
              decoration: InputDecoration(
                labelText: "Purpose of Meeting",
                hintText: "What would you like to discuss?",
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () {
              if (purpose == null || purpose!.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text("Please enter a purpose"),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }
              Navigator.pop(context);
              sendRequest(index, slot);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
            ),
            child: const Text("Send Request"),
          ),
        ],
      ),
    );
  }

  void sendRequest(int index, TimeSlotDisplay slot) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    
    setState(() => isLoading = true);
    
    try {
      final requestData = {
        "teacherId": widget.teacher['uid'],
        "teacherName": widget.teacher['name'],
        "studentId": user.uid,
        "studentName": user.displayName ?? user.email ?? "Student",
        "studentEmail": user.email ?? "",
        "timeSlot": slot.time,
        "period": slot.period,
        "purpose": purpose,
        "status": "pending",
        "createdAt": DateTime.now().toIso8601String(),
      };
      
      await dbRef.child("appointment_requests").push().set(requestData);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Request sent successfully!"),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Error: ${e.toString()}"),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        title: Text(
          widget.teacher['name'],
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Teacher Info Card
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
                            radius: 35,
                            backgroundColor: Colors.white,
                            child: Icon(Icons.person, size: 40, color: Colors.blue),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  widget.teacher['name'],
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  widget.teacher['branch'] ?? "Department",
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.9),
                                    fontSize: 14,
                                  ),
                                ),
                                if (widget.teacher['roomNo'] != null)
                                  Text(
                                    "Room: ${widget.teacher['roomNo']}",
                                    style: TextStyle(
                                      color: Colors.white.withValues(alpha: 0.9),
                                      fontSize: 12,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    
                    // Timetable Header
                    const Text(
                      "Weekly Schedule & Availability",
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    // Current Time Indicator
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.blue.shade100),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.blue.shade50,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.access_time, color: Colors.blue),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  "Current Time",
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey,
                                  ),
                                ),
                                Text(
                                  _getCurrentTimeSlot(),
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    
                    // Time Slots List
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: timeSlots.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final slot = timeSlots[index];
                        String status = getStatusForSlot(index);
                        Color statusColor = getStatusColor(status);
                        IconData statusIcon = getStatusIcon(status);
                        
                        return Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.grey.shade200,
                                blurRadius: 5,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: () => showRequestDialog(index, slot),
                              borderRadius: BorderRadius.circular(12),
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 50,
                                      height: 50,
                                      decoration: BoxDecoration(
                                        color: statusColor.withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Icon(
                                        statusIcon,
                                        color: statusColor,
                                        size: 28,
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            slot.period,
                                            style: const TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            slot.time,
                                            style: TextStyle(
                                              fontSize: 14,
                                              color: Colors.grey.shade600,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 6,
                                      ),
                                      decoration: BoxDecoration(
                                        color: statusColor.withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            statusIcon,
                                            size: 14,
                                            color: statusColor,
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            getStatusText(status),
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                              color: statusColor,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                    
                    const SizedBox(height: 20),
                    
                    // Legend
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "Status Legend",
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 16,
                            runSpacing: 8,
                            children: [
                              _buildLegendItem("Available", Colors.green, Icons.check_circle),
                              _buildLegendItem("Not Available", Colors.red, Icons.cancel),
                              _buildLegendItem("In Other Class", Colors.orange, Icons.class_),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
  
  Widget _buildLegendItem(String label, Color color, IconData icon) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
        ),
      ],
    );
  }
  
  String _getCurrentTimeSlot() {
    DateTime now = DateTime.now();
    String currentTime = "${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}";
    
    for (var slot in timeSlots) {
      List<String> times = slot.time.split(" - ");
      if (currentTime.compareTo(times[0]) >= 0 && currentTime.compareTo(times[1]) <= 0) {
        return "${slot.period} (${slot.time})";
      }
    }
    return "No active class";
  }
}

class TimeSlotDisplay {
  final String time;
  final String period;
  
  TimeSlotDisplay(this.time, this.period);
}