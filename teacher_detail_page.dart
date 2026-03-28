import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:intl/intl.dart';

class TimeSlotDisplay {
  final String time;
  final String period;
  const TimeSlotDisplay(this.time, this.period);
}

class TeacherDetailPage extends StatefulWidget {
  final Map<String, dynamic> teacher;
  const TeacherDetailPage({super.key, required this.teacher});

  @override
  State<TeacherDetailPage> createState() => _TeacherDetailPageState();
}

class _TeacherDetailPageState extends State<TeacherDetailPage> {
  final dbRef = FirebaseDatabase.instance.ref();
  Map<String, dynamic>? timetableData;
  Map<String, dynamic>? tempTimetableData;
  bool isLoading = true;
  bool isSendingRequest = false;
  bool isOnLeave = false;
  String? purpose;
  String today = "";
  int currentSlotIndex = -1;
  String currentSlotStatus = "available";
  Timer? _timer;
  final List<TimeSlotDisplay> timeSlots = [
    const TimeSlotDisplay("08:10 - 09:05", "Period 1"),
    const TimeSlotDisplay("09:05 - 10:00", "Period 2"),
    const TimeSlotDisplay("10:20 - 11:15", "Period 3"),
    const TimeSlotDisplay("11:15 - 12:10", "Period 4"),
    const TimeSlotDisplay("12:50 - 13:45", "Period 5"),
    const TimeSlotDisplay("13:45 - 14:40", "Period 6"),
    const TimeSlotDisplay("14:40 - 15:35", "Period 7"),
    const TimeSlotDisplay("15:35 - 16:30", "Period 8"),
  ];

  @override
  void initState() {
    super.initState();
    today = DateFormat('EEEE').format(DateTime.now());
    loadTimetable();
    _updateCurrentSlot();
    _timer = Timer.periodic(const Duration(minutes: 1), (timer) {
      _updateCurrentSlot();
    });
    dbRef
        .child("teacher_timetables")
        .child(widget.teacher['uid'])
        .onValue
        .listen((event) {
      if (event.snapshot.exists && mounted) {
        setState(() {
          timetableData = Map<String, dynamic>.from(event.snapshot.value as Map);
          _updateCurrentSlot();
        });
      }
    });
    dbRef
        .child("teacher_temp_timetables")
        .child(widget.teacher['uid'])
        .child(today.toLowerCase())
        .onValue
        .listen((event) {
      if (event.snapshot.exists && mounted) {
        setState(() {
          tempTimetableData = Map<String, dynamic>.from(event.snapshot.value as Map);
          isOnLeave = tempTimetableData!['onLeave'] ?? false;
          _updateCurrentSlot();
        });
      } else if (mounted) {
        setState(() {
          tempTimetableData = null;
          isOnLeave = false;
          _updateCurrentSlot();
        });
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _updateCurrentSlot() {
    DateTime now = DateTime.now();
    String currentTime = "${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}";
    int newSlotIndex = -1;
    for (int i = 0; i < timeSlots.length; i++) {
      List<String> times = timeSlots[i].time.split(" - ");
      if (currentTime.compareTo(times[0]) >= 0 && currentTime.compareTo(times[1]) <= 0) {
        newSlotIndex = i;
        break;
      }
    }
    if (newSlotIndex != currentSlotIndex) {
      setState(() {
        currentSlotIndex = newSlotIndex;
        if (currentSlotIndex != -1) {
          currentSlotStatus = getStatusForSlot(today, currentSlotIndex);
        }
      });
    } else if (currentSlotIndex != -1) {
      String newStatus = getStatusForSlot(today, currentSlotIndex);
      if (newStatus != currentSlotStatus) {
        setState(() {
          currentSlotStatus = newStatus;
        });
      }
    }
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
          _updateCurrentSlot();
        });
      }
      final tempSnapshot = await dbRef
          .child("teacher_temp_timetables")
          .child(widget.teacher['uid'])
          .child(today.toLowerCase())
          .get();
      if (tempSnapshot.exists && mounted) {
        setState(() {
          tempTimetableData = Map<String, dynamic>.from(tempSnapshot.value as Map);
          isOnLeave = tempTimetableData!['onLeave'] ?? false;
          _updateCurrentSlot();
        });
      }
    } catch (e) {
      debugPrint("Error loading timetable: $e");
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  String getStatusForSlot(String day, int slotIndex) {
    if (day == today && isOnLeave) {
      return "on_leave";
    }
    if (day == today && tempTimetableData != null) {
      String slotKey = "slot_${slotIndex + 1}";
      String? tempStatus = tempTimetableData![slotKey]?['status'];
      if (tempStatus != null) {
        return tempStatus;
      }
    }
    if (timetableData == null) return "available";
    String dayKey = day.toLowerCase();
    String slotKey = "slot_${slotIndex + 1}";
    return timetableData![dayKey]?[slotKey]?['status'] ?? "available";
  }

  String getRoomForSlot(String day, int slotIndex) {
    if (day == today && tempTimetableData != null) {
      String slotKey = "slot_${slotIndex + 1}";
      String? tempRoom = tempTimetableData![slotKey]?['tempRoomNo'];
      if (tempRoom != null && tempRoom.isNotEmpty) {
        return tempRoom;
      }
      String? globalTempRoom = tempTimetableData!['tempRoomNo'];
      if (globalTempRoom != null && globalTempRoom.isNotEmpty) {
        return globalTempRoom;
      }
    }
    return widget.teacher['roomNo'] ?? "Not specified";
  }

  String getStatusText(String status) {
    switch (status) {
      case "available":
        return "Available";
      case "not_available":
        return "Not Available";
      case "other_class":
        return "In Other Class";
      case "on_leave":
        return "On Leave";
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
      case "on_leave":
        return Colors.purple;
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
      case "on_leave":
        return Icons.beach_access;
      default:
        return Icons.help;
    }
  }

  void showRequestDialog() {
    if (currentSlotIndex == -1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("No active class at this time. Please check during class hours."),
          backgroundColor: Colors.grey,
        ),
      );
      return;
    }
    if (isOnLeave) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Teacher is on leave today. No appointments available."),
          backgroundColor: Colors.purple,
        ),
      );
      return;
    }
    if (currentSlotStatus != "available") {
      String roomInfo = "";
      if (currentSlotStatus == "other_class") {
        String roomNo = getRoomForSlot(today, currentSlotIndex);
        if (roomNo.isNotEmpty && roomNo != "Not specified") {
          roomInfo = "\n\n📍 Teacher will be in: $roomNo";
        }
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Teacher is ${getStatusText(currentSlotStatus).toLowerCase()} during this time slot.$roomInfo Please check back later."),
          backgroundColor: getStatusColor(currentSlotStatus),
          duration: const Duration(seconds: 4),
        ),
      );
      return;
    }
    final currentSlot = timeSlots[currentSlotIndex];
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Request Appointment"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Teacher: ${widget.teacher['name']}", style: const TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text("Current Time: ${currentSlot.time}"),
                  Text("Period: ${currentSlot.period}"),
                  if (widget.teacher['roomNo'] != null)
                    Text("Room: ${widget.teacher['roomNo']}"),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              "Purpose of Meeting",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            TextField(
              onChanged: (value) => purpose = value,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: "What would you like to discuss?",
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: Colors.grey.shade50,
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
              sendRequest(currentSlot);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
            ),
            child: const Text("Send Request"),
          ),
        ],
      ),
    );
  }

  void sendRequest(TimeSlotDisplay slot) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    setState(() => isSendingRequest = true);
    try {
      final requestId = DateTime.now().millisecondsSinceEpoch.toString();
      final requestData = {
        "requestId": requestId,
        "teacherId": widget.teacher['uid'],
        "teacherName": widget.teacher['name'],
        "studentId": user.uid,
        "studentName": user.displayName ?? user.email?.split('@')[0] ?? "Student",
        "studentEmail": user.email ?? "",
        "day": today,
        "timeSlot": slot.time,
        "period": slot.period,
        "purpose": purpose,
        "status": "pending",
        "createdAt": DateTime.now().toIso8601String(),
        "teacherRoom": widget.teacher['roomNo'] ?? "Not specified",
      };
      await dbRef
          .child("student_requests")
          .child(user.uid)
          .child(requestId)
          .set(requestData);
      await dbRef
          .child("teacher_requests")
          .child(widget.teacher['uid'])
          .child(requestId)
          .set(requestData);
      await dbRef
          .child("appointment_requests")
          .child(requestId)
          .set(requestData);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Request sent successfully! Check your dashboard for status."),
            backgroundColor: Colors.green,
          ),
        );
        purpose = null;
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Error sending request: ${e.toString()}"),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => isSendingRequest = false);
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
                                  Row(
                                    children: [
                                      const Icon(Icons.meeting_room, size: 14, color: Colors.white70),
                                      const SizedBox(width: 4),
                                      Text(
                                        "Room: ${widget.teacher['roomNo']}",
                                        style: TextStyle(
                                          color: Colors.white.withValues(alpha: 0.9),
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.grey.shade200,
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.blue.shade50,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(Icons.access_time, color: Colors.blue),
                              ),
                              const SizedBox(width: 12),
                              const Text(
                                "Current Time Slot",
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          if (isOnLeave)
                            Container(
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: Colors.purple.shade50,
                                borderRadius: BorderRadius.circular(15),
                                border: Border.all(color: Colors.purple, width: 2),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.beach_access, color: Colors.purple, size: 40),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          "On Leave Today",
                                          style: TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.purple,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          "Teacher is on leave today. No appointments available.",
                                          style: TextStyle(
                                            fontSize: 14,
                                            color: Colors.purple.shade700,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            )
                          else if (currentSlotIndex == -1)
                            const Center(
                              child: Padding(
                                padding: EdgeInsets.symmetric(vertical: 30),
                                child: Text(
                                  "No active class at this time",
                                  style: TextStyle(fontSize: 16, color: Colors.grey),
                                ),
                              ),
                            )
                          else ...[
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: getStatusColor(currentSlotStatus).withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(15),
                                border: Border.all(
                                  color: getStatusColor(currentSlotStatus),
                                  width: 2,
                                ),
                              ),
                              child: Column(
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              timeSlots[currentSlotIndex].period,
                                              style: const TextStyle(
                                                fontSize: 20,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                            const SizedBox(height: 8),
                                            Text(
                                              timeSlots[currentSlotIndex].time,
                                              style: TextStyle(
                                                fontSize: 16,
                                                color: Colors.grey.shade700,
                                              ),
                                            ),
                                            if (currentSlotStatus == "other_class") ...[
                                              const SizedBox(height: 8),
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                decoration: BoxDecoration(
                                                  color: Colors.orange.shade100,
                                                  borderRadius: BorderRadius.circular(8),
                                                ),
                                                child: Row(
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    const Icon(Icons.meeting_room, size: 14, color: Colors.orange),
                                                    const SizedBox(width: 4),
                                                    Text(
                                                      "Room: ${getRoomForSlot(today, currentSlotIndex)}",
                                                      style: const TextStyle(
                                                        fontSize: 12,
                                                        color: Colors.orange,
                                                        fontWeight: FontWeight.w500,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 16,
                                          vertical: 8,
                                        ),
                                        decoration: BoxDecoration(
                                          color: getStatusColor(currentSlotStatus),
                                          borderRadius: BorderRadius.circular(20),
                                        ),
                                        child: Row(
                                          children: [
                                            Icon(
                                              getStatusIcon(currentSlotStatus),
                                              color: Colors.white,
                                              size: 18,
                                            ),
                                            const SizedBox(width: 8),
                                            Text(
                                              getStatusText(currentSlotStatus),
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 20),
                            if (currentSlotStatus == "available")
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton.icon(
                                  onPressed: isSendingRequest ? null : showRequestDialog,
                                  icon: isSendingRequest
                                      ? const SizedBox(
                                          height: 20,
                                          width: 20,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Colors.white,
                                          ),
                                        )
                                      : const Icon(Icons.schedule),
                                  label: Text(
                                    isSendingRequest ? "Sending Request..." : "Request Appointment",
                                    style: const TextStyle(fontSize: 16),
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.green,
                                    padding: const EdgeInsets.symmetric(vertical: 14),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                ),
                              )
                            else
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade100,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.info_outline,
                                      color: Colors.grey.shade600,
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        currentSlotStatus == "other_class"
                                            ? "Teacher is in another class during this time slot. They will be available at: ${getRoomForSlot(today, currentSlotIndex)}"
                                            : "Teacher is ${getStatusText(currentSlotStatus).toLowerCase()} during this time slot. Please check back later.",
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: Colors.grey.shade600,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    if (tempTimetableData != null && !isOnLeave)
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.orange.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.orange, width: 1),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.timer, color: Colors.orange),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                "Temporary schedule active for today",
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.orange.shade700,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
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
}