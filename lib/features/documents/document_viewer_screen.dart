import 'package:file_saver/file_saver.dart';
import 'package:flutter/material.dart';
import 'package:pdfrx/pdfrx.dart';

import '../../core/api_client.dart';
import '../../widgets/common.dart';

class DocumentViewerScreen extends StatefulWidget {
  const DocumentViewerScreen({
    required this.title,
    required this.loader,
    super.key,
  });

  final String title;
  final Future<DownloadedFile> Function() loader;

  @override
  State<DocumentViewerScreen> createState() => _DocumentViewerScreenState();
}

class _DocumentViewerScreenState extends State<DocumentViewerScreen> {
  DownloadedFile? _file;
  String? _error;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final file = await widget.loader();
      if (mounted) setState(() => _file = file);
    } on ApiException catch (exception) {
      if (mounted) setState(() => _error = exception.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'Dokumen tidak dapat dibuka.');
    }
  }

  Future<void> _save() async {
    final file = _file;
    if (file == null || _saving) return;
    setState(() => _saving = true);
    try {
      final parts = file.fileName.split('.');
      final extension = parts.length > 1
          ? parts.removeLast().toLowerCase()
          : '';
      final name = parts.join('.').isEmpty ? 'dokumen' : parts.join('.');
      final path = await FileSaver.instance.saveFile(
        name: name,
        bytes: file.bytes,
        fileExtension: extension,
        mimeType: _mimeType(extension),
      );
      if (mounted) showMessage(context, 'Dokumen tersimpan: $path');
    } catch (_) {
      if (mounted) showMessage(context, 'Dokumen gagal disimpan. Coba lagi.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
          if (_file != null)
            IconButton(
              onPressed: _saving ? null : _save,
              tooltip: 'Unduh',
              icon: _saving
                  ? const SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator(strokeWidth: 2.2),
                    )
                  : const Icon(Icons.download_rounded),
            ),
          const SizedBox(width: 6),
        ],
      ),
      body: AppPageBackground(variant: 2, child: _body()),
    );
  }

  Widget _body() {
    final error = _error;
    if (error != null) return ErrorState(message: error, onRetry: _load);
    final file = _file;
    if (file == null) return const LoadingList();

    final type = file.contentType.toLowerCase();
    final name = file.fileName.toLowerCase();
    if (type.contains('pdf') || name.endsWith('.pdf')) {
      return ColoredBox(
        color: const Color(0xFFCED5D0),
        child: PdfViewer.data(file.bytes, sourceName: file.fileName),
      );
    }
    if (type.startsWith('image/') ||
        RegExp(r'\.(jpe?g|png|webp)$').hasMatch(name)) {
      return InteractiveViewer(
        minScale: .8,
        maxScale: 5,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Image.memory(file.bytes, fit: BoxFit.contain),
          ),
        ),
      );
    }
    return EmptyState(
      title: file.fileName,
      message: 'Pratinjau format ini belum tersedia. Gunakan tombol unduh.',
      icon: Icons.insert_drive_file_outlined,
    );
  }

  MimeType _mimeType(String extension) => switch (extension) {
    'pdf' => MimeType.pdf,
    'jpg' || 'jpeg' => MimeType.jpeg,
    'png' => MimeType.png,
    'webp' => MimeType.webp,
    _ => MimeType.other,
  };
}
