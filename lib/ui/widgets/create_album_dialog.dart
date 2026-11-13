import 'package:flutter/cupertino.dart';
import '../../core/theme/app_theme.dart';
import '../../services/folder_service.dart';

class CreateAlbumDialog extends StatefulWidget {
  const CreateAlbumDialog({super.key});

  /// Shows the dialog and returns the newly created album name if successful
  static Future<String?> show(BuildContext context) async {
    return await showCupertinoDialog<String>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => const CreateAlbumDialog(),
    );
  }

  @override
  State<CreateAlbumDialog> createState() => _CreateAlbumDialogState();
}

class _CreateAlbumDialogState extends State<CreateAlbumDialog> {
  final TextEditingController _controller = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final name = _controller.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Album name cannot be empty');
      return;
    }

    if (name.startsWith('.') ||
        name.toLowerCase() == 'private' ||
        name.toLowerCase() == 'locked' ||
        name.toLowerCase() == 'vault') {
      setState(() => _error = 'Reserved name. Choose another name.');
      return;
    }

    final success = await FolderService.instance.createAlbum(name);
    if (!mounted) return;

    if (success) {
      Navigator.of(context).pop(name);
    } else {
      setState(() => _error = 'Could not create album. Try another name.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = AppTheme.colors(context);

    return CupertinoAlertDialog(
      title: const Text('New Album'),
      content: Padding(
        padding: const EdgeInsets.only(top: 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CupertinoTextField(
              controller: _controller,
              autofocus: true,
              placeholder: 'Title',
              textCapitalization: TextCapitalization.words,
              style: TextStyle(color: c.textPrimary),
              decoration: BoxDecoration(
                color: c.surfaceGlass,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: c.glassBorder, width: 0.6),
              ),
              onSubmitted: (_) => _submit(),
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(
                _error!,
                style: TextStyle(
                  color: c.accentRose,
                  fontSize: 12,
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        CupertinoDialogAction(
          onPressed: () => Navigator.of(context).pop(null),
          child: const Text('Cancel'),
        ),
        CupertinoDialogAction(
          isDefaultAction: true,
          onPressed: _submit,
          child: const Text('Save'),
        ),
      ],
    );
  }
}
