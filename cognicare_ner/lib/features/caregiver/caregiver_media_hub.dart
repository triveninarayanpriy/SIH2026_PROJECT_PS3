import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:just_audio/just_audio.dart';
import 'package:record/record.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../l10n/app_localizations.dart';
import '../../core/models/media_item.dart';
import '../../core/services/local_db.dart';
import '../../core/services/sync_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/big_button.dart';
import '../../core/widgets/big_card.dart';
import '../../core/widgets/platform_media.dart';
import '../../core/widgets/voice_recorder_widget.dart';
import 'games_content_screen.dart';
import 'photo_viewer_screen.dart';

class CaregiverMediaHub extends StatefulWidget {
  final String patientId;

  const CaregiverMediaHub({Key? key, required this.patientId}) : super(key: key);

  @override
  _CaregiverMediaHubState createState() => _CaregiverMediaHubState();
}

class _CaregiverMediaHubState extends State<CaregiverMediaHub> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final ImagePicker _picker = ImagePicker();
  final AudioPlayer _audioPlayer = AudioPlayer();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 6, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      _showLabelDialog(image.path, 'familyFace');
    }
  }

  void _showLabelDialog(String filePath, String type) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Enter Name/Label', style: AppText.title()),
        content: TextField(
          controller: controller,
          style: AppText.body(),
          decoration: const InputDecoration(border: OutlineInputBorder()),
        ),
        actions: [
          ElevatedButton(
            onPressed: () async {
              final media = MediaItem(
                id: DateTime.now().millisecondsSinceEpoch.toString(),
                type: type,
                url: '',
                localPath: filePath,
                label: controller.text,
              );
              await SyncService.instance.saveMedia(widget.patientId, media);
              setState(() {});
              Navigator.pop(ctx);
            },
            child: Text('Save', style: AppText.body()),
          )
        ],
      ),
    );
  }

  Future<void> _pickMusic() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(type: FileType.audio);
    if (result != null && result.files.single.path != null) {
      _showLabelDialog(result.files.single.path!, 'music');
    }
  }

  Future<void> _addVoiceRecording() async {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        String name = '';
        String lang = 'en';
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
              child: Container(
                padding: const EdgeInsets.all(AppTheme.screenPadding),
                color: AppColors.surface,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Record Voice', style: AppText.title()),
                    const SizedBox(height: 16),
                    TextField(
                      onChanged: (val) => setModalState(() => name = val),
                      decoration: const InputDecoration(labelText: 'Family Member Name', border: OutlineInputBorder()),
                      style: AppText.body(),
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      value: lang,
                      items: const [
                        DropdownMenuItem(value: 'en', child: Text('English')),
                        DropdownMenuItem(value: 'hi', child: Text('Hindi')),
                        DropdownMenuItem(value: 'as', child: Text('Assamese')),
                        DropdownMenuItem(value: 'bn', child: Text('Bengali')),
                      ],
                      onChanged: (val) => setModalState(() => lang = val!),
                      decoration: const InputDecoration(border: OutlineInputBorder()),
                    ),
                    const SizedBox(height: 24),
                    VoiceRecorderWidget(
                      languageCode: lang,
                      name: name,
                      onRecordingComplete: (path) async {
                        final media = MediaItem(
                          id: DateTime.now().millisecondsSinceEpoch.toString(),
                          type: 'familyVoice',
                          url: '',
                          localPath: path,
                          label: name,
                        );
                        await SyncService.instance.saveMedia(widget.patientId, media);
                        setState(() {});
                        Navigator.pop(context);
                      },
                    ),
                  ],
                ),
              ),
            );
          }
        );
      }
    );
  }

  Widget _buildPhotosTab() {
    final photos = LocalDb.mediaByType('familyFace');
    return Column(
      children: [
        _guide('Add clear, close-up photos of family members and label each with '
            'their name. These power the face and name games.', Icons.photo_library),
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: BigButton(
            label: 'Add New Photo',
            icon: Icons.add_a_photo,
            color: AppColors.primary,
            onTap: _pickPhoto,
          ),
        ),
        Expanded(
          child: photos.isEmpty
              ? _emptyState('No photos yet', 'Tap “Add New Photo” to begin.', Icons.image_outlined)
              : GridView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                    childAspectRatio: 0.78,
                  ),
                  itemCount: photos.length,
                  itemBuilder: (context, index) {
                    final photo = photos[index];
                    return GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => PhotoViewerScreen(
                              imagePath: photo.localPath ?? photo.url,
                              label: photo.label ?? '',
                              onDelete: () {
                                LocalDb.deleteMedia(photo.id);
                                setState(() {});
                              },
                              onEditLabel: (newLabel) {
                                final updated = MediaItem(id: photo.id, type: photo.type, url: photo.url, localPath: photo.localPath, label: newLabel);
                                LocalDb.putMedia(updated);
                                setState(() {});
                              },
                            ),
                          ),
                        );
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(AppTheme.cardRadius),
                          border: Border.all(color: AppColors.border),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Expanded(
                              child: MediaImage(
                                  src: photo.localPath ?? photo.url, fit: BoxFit.cover),
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                              child: Text(
                                photo.label ?? '',
                                style: AppText.title().copyWith(fontSize: 17),
                                textAlign: TextAlign.center,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _emptyState(String title, String subtitle, IconData icon) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 72, color: AppColors.border),
            const SizedBox(height: 16),
            Text(title, style: AppText.title(), textAlign: TextAlign.center),
            const SizedBox(height: 6),
            Text(subtitle,
                style: AppText.body(color: AppColors.textMuted), textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }

  Widget _buildListTab(String type, String buttonLabel, IconData icon, VoidCallback onAdd) {
    final items = LocalDb.mediaByType(type);
    final bool isVoice = type == 'familyVoice';
    return Column(
      children: [
        _guide(
          isVoice
              ? 'Record short clips of family members saying who they are. The '
                  'patient hears these warm, familiar voices in the games.'
              : 'Add favourite songs or calming music. These play in Calm mode '
                  'and during relaxing moments.',
          isVoice ? Icons.record_voice_over : Icons.library_music,
        ),
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: BigButton(
            label: buttonLabel,
            icon: icon,
            color: AppColors.primary,
            onTap: onAdd,
          ),
        ),
        Expanded(
          child: items.isEmpty
              ? _emptyState('Nothing here yet', 'Use the button above to add.', icon)
              : ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: items.length,
            itemBuilder: (context, index) {
              final item = items[index];
              return BigCard(
                child: ListTile(
                  contentPadding: const EdgeInsets.all(16),
                  leading: CircleAvatar(
                    radius: 30,
                    backgroundColor: AppColors.primarySoft,
                    child: Icon(type == 'music' ? Icons.music_note : Icons.mic, size: 32, color: AppColors.primary),
                  ),
                  title: Text(item.label ?? '', style: AppText.title()),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                          icon: const Icon(Icons.play_circle_fill, size: 40, color: AppColors.secondary),
                          onPressed: () async {
                          final String src = (item.localPath?.isNotEmpty ?? false) ? item.localPath! : item.url;
                          try {
                            if (isLocalFilePath(src)) {
                              await _audioPlayer.setFilePath(src);
                            } else if (src.isNotEmpty) {
                              await _audioPlayer.setUrl(src);
                            }
                            _audioPlayer.play();
                          } catch (_) {}
                        },
                      ),
                      IconButton(
                          icon: const Icon(Icons.delete, size: 40, color: Colors.red),
                          onPressed: () {
                          LocalDb.deleteMedia(item.id);
                          setState(() {});
                        },
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildWelcomeTab() {
    return ListView(
      padding: const EdgeInsets.all(AppTheme.screenPadding),
      children: [
        Text('Configure Welcome Screen', style: AppText.title()),
        const SizedBox(height: 16),
        Text('Set a warm greeting that the patient sees when they open the app.', style: AppText.body()),
        const SizedBox(height: 32),
        BigButton(
          label: 'Set Welcome Photo',
          icon: Icons.image,
          color: AppColors.primary,
          onTap: () async {
            final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
            if (image != null) {
               final media = MediaItem(id: 'welcome_photo', type: 'welcome_photo', url: '', localPath: image.path, label: 'Welcome Photo');
               await LocalDb.putMedia(media);
               ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Welcome photo updated')));
            }
          },
        ),
        const SizedBox(height: 16),
        BigButton(
          label: 'Set Welcome Video',
          icon: Icons.video_library,
          color: AppColors.secondary,
          onTap: () async {
             FilePickerResult? result = await FilePicker.platform.pickFiles(type: FileType.video);
             if (result != null && result.files.single.path != null) {
               final media = MediaItem(id: 'welcome_video', type: 'welcome_video', url: '', localPath: result.files.single.path!, label: 'Welcome Video');
               await LocalDb.putMedia(media);
               ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Welcome video updated')));
             }
          },
        ),
      ],
    );
  }

  Widget _buildPromptsTab() {
    final loc = AppLocalizations.of(context);
    return ListView(
      padding: const EdgeInsets.all(AppTheme.screenPadding),
      children: [
        Text('Custom Game Prompts', style: AppText.title()),
        const SizedBox(height: 8),
        Text('Record your own voice for game questions. The patient will hear YOUR voice instead of the computer.',
            style: AppText.body(color: AppColors.textMuted).copyWith(fontSize: 18)),
        const SizedBox(height: 16),
        _PromptRecordCard(typeId: 'game_prompt_pattern', title: 'Pattern Game', spokenText: loc.whatComesNext, onChanged: () => setState(() {})),
        const SizedBox(height: 16),
        _PromptRecordCard(typeId: 'game_prompt_faces', title: 'Faces Game', spokenText: loc.whoIsThis, onChanged: () => setState(() {})),
        const SizedBox(height: 16),
        _PromptRecordCard(typeId: 'game_prompt_voice', title: 'Voice Game', spokenText: loc.whoseVoiceIsThis, onChanged: () => setState(() {})),
        const SizedBox(height: 16),
        _PromptRecordCard(typeId: 'game_prompt_correct', title: 'Correct Answer Response', spokenText: loc.veryGood, onChanged: () => setState(() {})),
        const SizedBox(height: 16),
        _PromptRecordCard(typeId: 'game_prompt_wrong', title: 'Wrong Answer Response', spokenText: loc.letsTryAgain, onChanged: () => setState(() {})),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F8FB),
      appBar: AppBar(
        title: const Text('Content Studio'),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          labelStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
          unselectedLabelStyle: const TextStyle(fontSize: 15),
          indicatorColor: AppColors.primary,
          indicatorWeight: 3,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textMuted,
          tabs: const [
            Tab(icon: Icon(Icons.photo_library), text: 'Photos'),
            Tab(icon: Icon(Icons.record_voice_over), text: 'Voices'),
            Tab(icon: Icon(Icons.library_music), text: 'Music'),
            Tab(icon: Icon(Icons.waving_hand), text: 'Welcome'),
            Tab(icon: Icon(Icons.gamepad), text: 'Prompts'),
            Tab(icon: Icon(Icons.auto_awesome), text: 'Games'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildPhotosTab(),
          _buildListTab('familyVoice', 'Record New Voice', Icons.mic, _addVoiceRecording),
          _buildListTab('music', 'Add Music Track', Icons.library_music, _pickMusic),
          _buildWelcomeTab(),
          _buildPromptsTab(),
          const GamesContentScreen(embedded: true),
        ],
      ),
    );
  }

  /// A friendly guidance banner shown at the top of each tab.
  static Widget _guide(String text, IconData icon) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.primarySoft,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppColors.primary, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Text(text,
                style: AppText.body(color: AppColors.primaryDark).copyWith(fontSize: 13.5)),
          ),
        ],
      ),
    );
  }
}

class _PromptRecordCard extends StatefulWidget {
  final String typeId;
  final String title;
  final String spokenText;
  final VoidCallback onChanged;

  const _PromptRecordCard({
    Key? key,
    required this.typeId,
    required this.title,
    required this.spokenText,
    required this.onChanged,
  }) : super(key: key);

  @override
  State<_PromptRecordCard> createState() => _PromptRecordCardState();
}

class _PromptRecordCardState extends State<_PromptRecordCard> {
  final AudioRecorder _recorder = AudioRecorder();
  final AudioPlayer _player = AudioPlayer();
  bool _isRecording = false;
  bool _isPlaying = false;
  String? _recordedPath;

  @override
  void initState() {
    super.initState();
    final existing = LocalDb.mediaByType(widget.typeId).firstOrNull;
    if (existing != null && existing.localPath != null) {
      _recordedPath = existing.localPath;
    }
  }

  @override
  void dispose() {
    _recorder.dispose();
    _player.dispose();
    super.dispose();
  }

  Future<void> _startRecording() async {
    final status = await Permission.microphone.request();
    if (status.isGranted) {
      final dir = await getApplicationDocumentsDirectory();
      final path = '${dir.path}/${widget.typeId}_${DateTime.now().millisecondsSinceEpoch}.m4a';
      await _recorder.start(const RecordConfig(), path: path);
      setState(() => _isRecording = true);
    }
  }

  Future<void> _stopRecording() async {
    final path = await _recorder.stop();
    setState(() {
      _isRecording = false;
      _recordedPath = path;
    });
  }

  Future<void> _playRecording() async {
    if (_recordedPath != null) {
      setState(() => _isPlaying = true);
      try {
        if (isLocalFilePath(_recordedPath)) {
          await _player.setFilePath(_recordedPath!);
        } else {
          await _player.setUrl(_recordedPath!);
        }
        await _player.play();
      } catch (_) {}
      setState(() => _isPlaying = false);
    }
  }

  Future<void> _saveRecording() async {
    if (_recordedPath != null) {
      final media = MediaItem(
        id: widget.typeId,
        type: widget.typeId,
        url: '',
        localPath: _recordedPath,
        label: widget.title,
      );
      await LocalDb.putMedia(media);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Prompt saved!'))
        );
      }
      widget.onChanged();
    }
  }

  Future<void> _deleteRecording() async {
    final existing = LocalDb.mediaByType(widget.typeId).firstOrNull;
    if (existing != null) {
      LocalDb.deleteMedia(existing.id);
    }
    setState(() => _recordedPath = null);
    widget.onChanged();
  }

  @override
  Widget build(BuildContext context) {
    return BigCard(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(widget.title, style: AppText.title().copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text('Please say:', style: AppText.body(color: AppColors.primary)),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.primarySoft,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.primary),
              ),
              child: Text(
                widget.spokenText,
                style: AppText.body().copyWith(color: AppColors.primary, fontSize: 28, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 16),
            if (_recordedPath == null) ...[
              _isRecording
                  ? ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.red, padding: const EdgeInsets.all(16)),
                      icon: const Icon(Icons.stop),
                      label: const Text('Stop Recording', style: TextStyle(fontSize: 20, color: Colors.white)),
                      onPressed: _stopRecording,
                    )
                  : ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, padding: const EdgeInsets.all(16)),
                      icon: const Icon(Icons.mic, color: Colors.white),
                      label: const Text('Start Recording', style: TextStyle(fontSize: 20, color: Colors.white)),
                      onPressed: _startRecording,
                    ),
            ] else ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  IconButton(
                    icon: Icon(_isPlaying ? Icons.stop : Icons.play_arrow, size: 40),
                    color: AppColors.secondary,
                    onPressed: _isPlaying ? () => _player.stop() : _playRecording,
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete, size: 40),
                    color: Colors.red,
                    onPressed: _deleteRecording,
                  ),
                  ElevatedButton(
                    onPressed: _saveRecording,
                    style: ElevatedButton.styleFrom(backgroundColor: AppColors.success),
                    child: const Text('Save', style: TextStyle(color: Colors.white)),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
