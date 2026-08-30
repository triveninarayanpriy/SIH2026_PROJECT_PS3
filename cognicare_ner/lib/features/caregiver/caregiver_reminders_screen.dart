import 'package:flutter/material.dart';
import '../../core/models/reminder.dart';
import '../../core/services/local_db.dart';
import '../../core/services/sync_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/big_button.dart';
import '../../core/widgets/big_card.dart';
import '../../core/widgets/voice_recorder_widget.dart';

class CaregiverRemindersScreen extends StatefulWidget {
  final String patientId;

  const CaregiverRemindersScreen({Key? key, required this.patientId}) : super(key: key);

  @override
  _CaregiverRemindersScreenState createState() => _CaregiverRemindersScreenState();
}

class _CaregiverRemindersScreenState extends State<CaregiverRemindersScreen> {
  List<Reminder> _reminders = [];

  @override
  void initState() {
    super.initState();
    _loadReminders();
  }

  void _loadReminders() {
    setState(() {
      _reminders = LocalDb.allReminders();
    });
  }

  Future<void> _deleteReminder(String id) async {
    await LocalDb.deleteReminder(id);
    _loadReminders();
  }

  void _showAddEditDialog([Reminder? reminder]) {
    final titleController = TextEditingController(text: reminder?.title ?? '');
    String type = reminder?.type ?? 'medicine';
    TimeOfDay time = reminder != null ? 
      TimeOfDay(hour: int.parse(reminder.time.split(':')[0]), minute: int.parse(reminder.time.split(':')[1])) : 
      TimeOfDay.now();
    bool repeatDaily = reminder?.repeatDaily ?? true;
    String? audioPath = reminder?.audioLocalPath;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          return Container(
            height: MediaQuery.of(context).size.height * 0.9,
            decoration: const BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
            ),
            padding: const EdgeInsets.all(AppTheme.screenPadding),
            child: ListView(
              children: [
                Text(reminder == null ? 'Add Reminder' : 'Edit Reminder', style: AppText.title()),
                const SizedBox(height: 24),
                
                DropdownButtonFormField<String>(
                  value: type,
                  decoration: const InputDecoration(labelText: 'Type', border: OutlineInputBorder()),
                  items: ['medicine', 'hydration', 'meal', 'appointment'].map((t) => 
                    DropdownMenuItem(value: t, child: Text(t.toUpperCase(), style: AppText.body()))
                  ).toList(),
                  onChanged: (val) {
                    if (val != null) setModalState(() => type = val);
                  },
                ),
                const SizedBox(height: 16),
                
                TextField(
                  controller: titleController,
                  style: AppText.body(),
                  decoration: const InputDecoration(
                    labelText: 'Title',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                
                ListTile(
                  title: Text('Time', style: AppText.body()),
                  trailing: Text(time.format(context), style: AppText.title().copyWith(color: AppColors.primary)),
                  onTap: () async {
                    final t = await showTimePicker(context: context, initialTime: time);
                    if (t != null) setModalState(() => time = t);
                  },
                ),
                
                SwitchListTile(
                  title: Text('Repeat Daily', style: AppText.body()),
                  activeColor: AppColors.success,
                  value: repeatDaily,
                  onChanged: (val) => setModalState(() => repeatDaily = val),
                ),
                
                const SizedBox(height: 16),
                Text('Add Voice Prompt (Optional)', style: AppText.title().copyWith(fontSize: 20)),
                const SizedBox(height: 8),
                VoiceRecorderWidget(
                  languageCode: 'en', // Can be loaded from settings
                  name: 'Caregiver',
                  onRecordingComplete: (path) {
                    audioPath = path;
                  },
                ),
                const SizedBox(height: 24),
                
                BigButton(
                  label: 'Save Reminder',
                  icon: Icons.save,
                  color: AppColors.primary,
                  onTap: () async {
                    final now = DateTime.now();
                    
                    final newReminder = Reminder(
                      id: reminder?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
                      type: type,
                      title: titleController.text,
                      time: '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}',
                      repeatDaily: repeatDaily,
                      audioLocalPath: audioPath,
                      audioClipUrl: '',
                    );
                    
                    await SyncService.instance.saveReminder(widget.patientId, newReminder);
                    _loadReminders();
                    Navigator.pop(ctx);
                  },
                ),
              ],
            ),
          );
        }
      ),
    );
  }

  IconData _getIconForType(String type) {
    switch (type) {
      case 'medicine': return Icons.medication;
      case 'hydration': return Icons.water_drop;
      case 'meal': return Icons.restaurant;
      case 'appointment': return Icons.event;
      default: return Icons.notifications;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Reminders'),
      ),
      body: _reminders.isEmpty 
        ? Center(child: Text('No reminders set yet.', style: AppText.body()))
        : ListView.builder(
            padding: const EdgeInsets.all(AppTheme.screenPadding),
            itemCount: _reminders.length,
            itemBuilder: (context, index) {
              final r = _reminders[index];
              return BigCard(
                child: ListTile(
                  contentPadding: const EdgeInsets.all(16),
                  leading: CircleAvatar(
                    radius: 30,
                    backgroundColor: AppColors.primarySoft,
                    child: Icon(_getIconForType(r.type), size: 36, color: AppColors.primary),
                  ),
                  title: Text(r.title, style: AppText.title()),
                  subtitle: Text(
                    '${TimeOfDay(hour: int.parse(r.time.split(":")[0]), minute: int.parse(r.time.split(":")[1])).format(context)} ${r.repeatDaily ? "(Daily)" : ""}',
                    style: AppText.body().copyWith(color: AppColors.secondary),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (r.audioLocalPath != null)
                        const Icon(Icons.mic, color: AppColors.gentleWarning, size: 28),
                      IconButton(
                        icon: const Icon(Icons.edit, size: 32),
                        onPressed: () => _showAddEditDialog(r),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red, size: 32),
                        onPressed: () => _deleteReminder(r.id),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.primary,
        onPressed: () => _showAddEditDialog(),
        icon: const Icon(Icons.add, size: 32),
        label: Text('Add Reminder', style: AppText.button().copyWith(fontSize: 20)),
      ),
    );
  }
}
