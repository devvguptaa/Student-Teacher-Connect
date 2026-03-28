import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';

class TimeSlot {
  final String time;
  final String period;
  const TimeSlot(this.time, this.period);
}

class TeacherTimetablesPage extends StatefulWidget {
  const TeacherTimetablesPage({super.key});

  @override
  State<TeacherTimetablesPage> createState() => _TeacherTimetablesPageState();
}

class _TeacherTimetablesPageState extends State<TeacherTimetablesPage> {
  final user = FirebaseAuth.instance.currentUser;
  final dbRef = FirebaseDatabase.instance.ref();
  bool isLoading = true;
  Map<String, dynamic>? timetableData;
  final List<String> daysOfWeek = [
    "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"
  ];
  final List<TimeSlot> timeSlots = [
    const TimeSlot("08:10 - 09:05", "Period 1"),
    const TimeSlot("09:05 - 10:00", "Period 2"),
    const TimeSlot("10:20 - 11:15", "Period 3"),
    const TimeSlot("11:15 - 12:10", "Period 4"),
    const TimeSlot("12:50 - 13:45", "Period 5"),
    const TimeSlot("13:45 - 14:40", "Period 6"),
    const TimeSlot("14:40 - 15:35", "Period 7"),
    const TimeSlot("15:35 - 16:30", "Period 8"),
  ];

  @override
  void initState() {
    super.initState();
    loadTimetable();
  }

  Future<void> loadTimetable() async {
    if (user == null) return;
    try {
      final snapshot = await dbRef
          .child("teacher_timetables")
          .child(user!.uid)
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

  Future<void> updateTimeSlot(String day, int slotIndex, String status) async {
    if (user == null) return;
    try {
      String dayKey = day.toLowerCase();
      String slotKey = "slot_${slotIndex + 1}";
      Map<String, dynamic> slotData = {
        "time": timeSlots[slotIndex].time,
        "period": timeSlots[slotIndex].period,
        "status": status,
        "updatedAt": DateTime.now().toIso8601String(),
      };
      await dbRef
          .child("teacher_timetables")
          .child(user!.uid)
          .child(dayKey)
          .child(slotKey)
          .set(slotData);
      setState(() {
        if (timetableData == null) {
          timetableData = {};
        }
        if (timetableData![dayKey] == null) {
          timetableData![dayKey] = {};
        }
        timetableData![dayKey][slotKey] = slotData;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("${day}: ${_getStatusText(status)}"),
            backgroundColor: _getStatusColor(status),
            duration: const Duration(seconds: 2),
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

  String _getStatusText(String status) {
    switch (status) {
      case "available":
        return "Available";
      case "not_available":
        return "Not Available";
      case "other_class":
        return "Available in Other Class";
      default:
        return status;
    }
  }

  Color _getStatusColor(String status) {
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

  String _getCurrentStatus(String day, int slotIndex) {
    if (timetableData == null) return "available";
    String dayKey = day.toLowerCase();
    String slotKey = "slot_${slotIndex + 1}";
    return timetableData![dayKey]?[slotKey]?['status'] ?? "available";
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: daysOfWeek.length,
      child: Scaffold(
        backgroundColor: Colors.grey.shade50,
        appBar: AppBar(
          elevation: 0,
          backgroundColor: Colors.white,
          foregroundColor: Colors.black87,
          title: const Text(
            "My Weekly Timetable",
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          bottom: TabBar(
            isScrollable: true,
            labelColor: Colors.blue.shade700,
            unselectedLabelColor: Colors.grey.shade600,
            indicatorColor: Colors.blue.shade700,
            tabs: daysOfWeek.map((day) => Tab(text: day)).toList(),
          ),
        ),
        body: isLoading
            ? const Center(child: CircularProgressIndicator())
            : TabBarView(
                children: daysOfWeek.map((day) {
                  return _buildDaySchedule(day);
                }).toList(),
              ),
      ),
    );
  }

  Widget _buildDaySchedule(String day) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Row(
              children: [
                Icon(Icons.info, color: Colors.blue),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    "Update your availability for each time slot. Students will see your real-time status.",
                    style: TextStyle(fontSize: 14),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Text(
            "$day Schedule",
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: timeSlots.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final slot = timeSlots[index];
              String currentStatus = _getCurrentStatus(day, index);
              Color statusColor = _getStatusColor(currentStatus);
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
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Container(
                            width: 60,
                            height: 60,
                            decoration: BoxDecoration(
                              color: Colors.blue.shade50,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Center(
                              child: Text(
                                "${index + 1}",
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blue.shade700,
                                ),
                              ),
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
                              border: Border.all(
                                color: statusColor,
                                width: 1,
                              ),
                            ),
                            child: Text(
                              _getStatusText(currentStatus),
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: statusColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1),
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        children: [
                          _buildStatusButton(
                            "Available",
                            "available",
                            currentStatus,
                            day,
                            index,
                            Colors.green,
                          ),
                          const SizedBox(width: 8),
                          _buildStatusButton(
                            "Not Available",
                            "not_available",
                            currentStatus,
                            day,
                            index,
                            Colors.red,
                          ),
                          const SizedBox(width: 8),
                          _buildStatusButton(
                            "Other Class",
                            "other_class",
                            currentStatus,
                            day,
                            index,
                            Colors.orange,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildStatusButton(
    String label,
    String status,
    String currentStatus,
    String day,
    int index,
    Color color,
  ) {
    bool isActive = currentStatus == status;
    return Expanded(
      child: ElevatedButton(
        onPressed: () => updateTimeSlot(day, index, status),
        style: ElevatedButton.styleFrom(
          backgroundColor: isActive ? color : Colors.white,
          foregroundColor: isActive ? Colors.white : color,
          elevation: 0,
          side: BorderSide(color: color),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          padding: const EdgeInsets.symmetric(vertical: 10),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}