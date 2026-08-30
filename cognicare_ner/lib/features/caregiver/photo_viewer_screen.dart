import 'dart:io';
import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text.dart';
import '../../core/theme/app_theme.dart';


class PhotoViewerScreen extends StatefulWidget {
  final String imagePath;
  final String label;
  final VoidCallback onDelete;
  final ValueChanged<String> onEditLabel;

  const PhotoViewerScreen({
    Key? key,
    required this.imagePath,
    required this.label,
    required this.onDelete,
    required this.onEditLabel,
  }) : super(key: key);

  @override
  _PhotoViewerScreenState createState() => _PhotoViewerScreenState();
}

class _PhotoViewerScreenState extends State<PhotoViewerScreen> {
  late String currentLabel;

  @override
  void initState() {
    super.initState();
    currentLabel = widget.label;
  }

  void _showEditDialog() {
    final controller = TextEditingController(text: currentLabel);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Edit Name', style: AppText.title()),
        content: TextField(
          controller: controller,
          style: AppText.body(),
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            labelText: 'Name',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: AppText.body()),
          ),
          ElevatedButton(
            onPressed: () {
              setState(() {
                currentLabel = controller.text;
              });
              widget.onEditLabel(currentLabel);
              Navigator.pop(ctx);
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            child: Text('Save', style: AppText.body().copyWith(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _confirmDelete() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete Photo?', style: AppText.title()),
        content: Text('Are you sure you want to remove this photo?', style: AppText.body()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: AppText.body()),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              widget.onDelete();
              Navigator.pop(context); // Close viewer screen
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text('Delete', style: AppText.body().copyWith(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit, size: 32),
            onPressed: _showEditDialog,
            tooltip: 'Edit Name',
          ),
          IconButton(
            icon: const Icon(Icons.delete, size: 32, color: Colors.redAccent),
            onPressed: _confirmDelete,
            tooltip: 'Delete',
          ),
        ],
      ),
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          Center(
            child: InteractiveViewer(
              minScale: 1.0,
              maxScale: 4.0,
              child: Container(
                width: double.infinity,
                height: MediaQuery.of(context).size.height * 0.85,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(AppTheme.cardRadius),
                  border: Border.all(color: Colors.white24, width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.5),
                      blurRadius: 20,
                      spreadRadius: 5,
                    )
                  ],
                ),
                margin: const EdgeInsets.all(AppTheme.screenPadding),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(AppTheme.cardRadius - 2),
                  child: Image.file(
                    File(widget.imagePath),
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 40,
            left: AppTheme.screenPadding,
            right: AppTheme.screenPadding,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.7),
                borderRadius: BorderRadius.circular(AppTheme.cardRadius),
              ),
              child: Text(
                currentLabel,
                textAlign: TextAlign.center,
                style: AppText.title().copyWith(color: Colors.white, fontSize: 36),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
