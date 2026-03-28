import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:intl/intl.dart';

class TempTimeSlot {
  final String time;
  final String period;
  const TempTimeSlot(this.time, this.period);
}

class TeacherTempTimetablePage extends StatefulWidget {
  const TeacherTempTimetablePage({super.key});

  @override
  State<TeacherTempTimetablePage> createState() => _TeacherTempTimetablePageState();
}

class _TeacherTempTimetablePageState extends State<TeacherTempTimetablePage> {
  final user = FirebaseAuth.instance.currentUser;
  final dbRef = FirebaseDatabase.instance.ref();
  bool isLoading = true;
  Map<String, dynamic>? tempTimetableData;
  Map<String, dynamic>? teacherData;
  bool isOnLeave = false;
  String today = "";
  String? tempRoomNo;
  final List<TempTimeSlot> timeSlots = [
    const TempTimeSlot("08:10 - 09:05", "Period 1"),
    const TempTimeSlot("09:05 - 10:00", "Period 2"),
    const TempTimeSlot("10:20 - 11:15", "Period 3"),
    const TempTimeSlot("11:15 - 12:10", "Period 4"),
    const TempTimeSlot("12:50 - 13:45", "Period 5"),
    const TempTimeSlot("13:45 - 14:40", "Period 6"),
    const TempTimeSlot("14:40 - 15:35", "Period 7"),
    const TempTimeSlot("15:35 - 16:30", "Period 8"),
  ];

  @override
  void initState() {
    super.initState();
    today = DateFormat('EEEE').format(DateTime.now());
    loadTeacherData();
    loadTempTimetable();
  }

  Future<void> loadTeacherData() async {
    if (user == null) return;
    try {
      final snapshot = await dbRef.child("users/${user!.uid}").get();
      if (snapshot.exists && mounted) {
        setState(() {
          teacherData = Map<String, dynamic>.from(snapshot.value as Map);
          tempRoomNo = teacherData?['tempRoomNo'];
        });
      }
    } catch (e) {
      debugPrint("Error loading teacher data: $e");
    }
  }

  Future<void> loadTempTimetable() async {
    if (user == null) return;
    try {
      final snapshot = await dbRef
          .child("teacher_temp_timetables")
          .child(user!.uid)
          .child(today.toLowerCase())
          .get();
      if (snapshot.exists && mounted) {
        setState(() {
          tempTimetableData = Map<String, dynamic>.from(snapshot.value as Map);
          isOnLeave = tempTimetableData!['onLeave'] ?? false;
          tempRoomNo = tempTimetableData!['tempRoomNo'];
        });
      }
    } catch (e) {
      debugPrint("Error loading temp timetable: $e");
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  Future<void> updateOnLeaveStatus(bool value) async {
    if (user == null) return;
    setState(() => isLoading = true);
    try {
      if (value) {
        await dbRef
            .child("teacher_temp_timetables")
            .child(user!.uid)
            .child(today.toLowerCase())
            .set({
              "onLeave": true,
              "updatedAt": DateTime.now().toIso8601String(),
            });
      } else {
        await dbRef
            .child("teacher_temp_timetables")
            .child(user!.uid)
            .child(today.toLowerCase())
            .remove();
      }
      await loadTempTimetable();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: value 
                ? Text("Marked as On Leave for today. Students cannot request appointments.")
                : Text("Removed On Leave status. You can now set individual slot statuses."),
            backgroundColor: value ? Colors.orange : Colors.green,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: ${e.toString()}"), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  Future<void> showRoomInputDialog(int slotIndex, String currentStatus) async {
    TextEditingController roomController = TextEditingController(text: tempRoomNo ?? teacherData?['roomNo'] ?? '');
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Enter Current Room Number"),
        content: TextField(
          controller: roomController,
          decoration: const InputDecoration(
            labelText: "Room Number",
            hintText: "e.g., Room 201, Lab 3",
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () async {
              String roomNo = roomController.text.trim();
              if (roomNo.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Please enter a room number"), backgroundColor: Colors.red),
                );
                return;
              }
              Navigator.pop(context);
              await updateTimeSlot(slotIndex, "other_class", roomNo);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
            ),
            child: const Text("Set & Update"),
          ),
        ],
      ),
    );
  }

  Future<void> updateTimeSlot(int slotIndex, String status, [String? roomNo]) async {
    if (user == null) return;
    if (isOnLeave) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("You are on leave today. Cannot modify individual slots."),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    try {
      String slotKey = "slot_${slotIndex + 1}";
      Map<String, dynamic> slotData = {
        "time": timeSlots[slotIndex].time,
        "period": timeSlots[slotIndex].period,
        "status": status,
        "updatedAt": DateTime.now().toIso8601String(),
      };
      if (status == "other_class" && roomNo != null) {
        slotData["tempRoomNo"] = roomNo;
      }
      Map<String, dynamic> updates = {
        slotKey: slotData,
        "onLeave": false,
        "updatedAt": DateTime.now().toIso8601String(),
      };
      if (status == "other_class" && roomNo != null) {
        updates["tempRoomNo"] = roomNo;
      }
      await dbRef
          .child("teacher_temp_timetables")
          .child(user!.uid)
          .child(today.toLowerCase())
          .update(updates);
      await loadTempTimetable();
      if (mounted) {
        String message = "Status updated to ${_getStatusText(status)}";
        if (status == "other_class" && roomNo != null) {
          message += " (Room: $roomNo)";
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
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

  Future<void> clearTempTimetable() async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Clear Temporary Timetable"),
        content: const Text("This will revert to your permanent timetable. Are you sure?"),
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
                await dbRef
                    .child("teacher_temp_timetables")
                    .child(user!.uid)
                    .child(today.toLowerCase())
                    .remove();
                await loadTempTimetable();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text("Temporary timetable cleared. Using permanent schedule."),
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
            },
            child: const Text("Clear", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
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

  String _getCurrentStatus(int slotIndex) {
    if (isOnLeave) return "not_available";
    if (tempTimetableData == null) return "available";
    String slotKey = "slot_${slotIndex + 1}";
    return tempTimetableData![slotKey]?['status'] ?? "available";
  }
  
  String _getTempRoomNoForSlot(int slotIndex) {
    if (tempTimetableData == null) return "";
    String slotKey = "slot_${slotIndex + 1}";
    return tempTimetableData![slotKey]?['tempRoomNo'] ?? tempTimetableData!['tempRoomNo'] ?? teacherData?['roomNo'] ?? "";
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
          "Temporary Timetable",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.red),
            onPressed: clearTempTimetable,
            tooltip: 'Clear Temporary Timetable',
          ),
        ],
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
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: isOnLeave ? Colors.red.shade50 : Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isOnLeave ? Colors.red : Colors.orange,
                          width: 1,
                        ),
                      ),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Icon(
                                isOnLeave ? Icons.beach_access : Icons.timer,
                                color: isOnLeave ? Colors.red : Colors.orange,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  isOnLeave 
                                      ? "You are marked as ON LEAVE for today"
                                      : "Temporary Schedule for $today",
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: isOnLeave ? Colors.red : Colors.orange,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          if (!isOnLeave)
                            Text(
                              "This overrides your permanent timetable for today only. Changes will be automatically cleared tomorrow.",
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          if (isOnLeave)
                            Text(
                              "You are on leave today. No appointment requests will be accepted. Students will see you as unavailable for all slots.",
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.red.shade700,
                              ),
                            ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton(
                                  onPressed: () => updateOnLeaveStatus(!isOnLeave),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: isOnLeave ? Colors.green : Colors.red,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                  ),
                                  child: Text(
                                    isOnLeave ? "Cancel Leave" : "Mark as On Leave",
                                    style: const TextStyle(color: Colors.white),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    if (!isOnLeave) ...[
                      Text(
                        "$today's Schedule (Temporary)",
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
                          String currentStatus = _getCurrentStatus(index);
                          Color statusColor = _getStatusColor(currentStatus);
                          String tempRoom = _getTempRoomNoForSlot(index);
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
                                          color: Colors.orange.shade50,
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: Center(
                                          child: Text(
                                            "${index + 1}",
                                            style: TextStyle(
                                              fontSize: 24,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.orange.shade700,
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
                                            if (currentStatus == "other_class" && tempRoom.isNotEmpty)
                                              Padding(
                                                padding: const EdgeInsets.only(top: 4),
                                                child: Row(
                                                  children: [
                                                    const Icon(Icons.meeting_room, size: 12, color: Colors.orange),
                                                    const SizedBox(width: 4),
                                                    Text(
                                                      "Room: $tempRoom",
                                                      style: TextStyle(
                                                        fontSize: 11,
                                                        color: Colors.orange.shade700,
                                                        fontWeight: FontWeight.w500,
                                                      ),
                                                    ),
                                                  ],
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
                                        index,
                                        Colors.green,
                                      ),
                                      const SizedBox(width: 8),
                                      _buildStatusButton(
                                        "Not Available",
                                        "not_available",
                                        currentStatus,
                                        index,
                                        Colors.red,
                                      ),
                                      const SizedBox(width: 8),
                                      _buildStatusButton(
                                        "Other Class",
                                        "other_class",
                                        currentStatus,
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
                    const SizedBox(height: 20),
                    if (!isOnLeave)
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.info_outline, color: Colors.grey),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                "This temporary schedule will be active for today only. Tomorrow, your permanent timetable will be used again.",
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade600,
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

  Widget _buildStatusButton(
    String label,
    String status,
    String currentStatus,
    int index,
    Color color,
  ) {
    bool isActive = currentStatus == status;
    return Expanded(
      child: ElevatedButton(
        onPressed: () {
          if (status == "other_class") {
            showRoomInputDialog(index, currentStatus);
          } else {
            updateTimeSlot(index, status);
          }
        },
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