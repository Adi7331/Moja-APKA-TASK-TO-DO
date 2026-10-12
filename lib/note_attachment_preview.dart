import 'dart:io';

import 'package:flutter/material.dart';
import 'package:pdfx/pdfx.dart';
import 'package:url_launcher/url_launcher.dart';

import 'note_item.dart';

enum NoteAttachmentPreviewKind { image, pdf, text, external }

NoteAttachmentPreviewKind noteAttachmentPreviewKind(NoteAttachment attachment) {
  if (attachment.mimeType.startsWith('image/')) {
    return NoteAttachmentPreviewKind.image;
  }
  final extension = attachment.fileName.split('.').last.toLowerCase();
  if (attachment.mimeType == 'application/pdf' || extension == 'pdf') {
    return NoteAttachmentPreviewKind.pdf;
  }
  if (attachment.mimeType.startsWith('text/') ||
      const {'md', 'markdown', 'csv', 'log'}.contains(extension)) {
    return NoteAttachmentPreviewKind.text;
  }
  return NoteAttachmentPreviewKind.external;
}

class NoteAttachmentPreviewScreen extends StatefulWidget {
  const NoteAttachmentPreviewScreen({
    super.key,
    required this.attachment,
    required this.file,
  });

  final NoteAttachment attachment;
  final File file;

  @override
  State<NoteAttachmentPreviewScreen> createState() =>
      _NoteAttachmentPreviewScreenState();
}

class _NoteAttachmentPreviewScreenState
    extends State<NoteAttachmentPreviewScreen> {
  PdfController? _pdfController;
  String? _text;
  Object? _loadError;

  NoteAttachmentPreviewKind get _kind =>
      noteAttachmentPreviewKind(widget.attachment);

  @override
  void initState() {
    super.initState();
    switch (_kind) {
      case NoteAttachmentPreviewKind.pdf:
        _pdfController = PdfController(
          document: PdfDocument.openFile(widget.file.path),
        );
        break;
      case NoteAttachmentPreviewKind.text:
        _loadText();
        break;
      case NoteAttachmentPreviewKind.image:
      case NoteAttachmentPreviewKind.external:
        break;
    }
  }

  Future<void> _loadText() async {
    try {
      final text = await widget.file.readAsString();
      if (mounted) setState(() => _text = text);
    } on Object catch (error) {
      if (mounted) setState(() => _loadError = error);
    }
  }

  @override
  void dispose() {
    _pdfController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(widget.attachment.fileName)),
    body: SafeArea(child: _buildPreview(context)),
  );

  Widget _buildPreview(BuildContext context) => switch (_kind) {
    NoteAttachmentPreviewKind.image => InteractiveViewer(
      minScale: .5,
      maxScale: 5,
      child: Center(
        child: Image.file(
          widget.file,
          fit: BoxFit.contain,
          errorBuilder: (_, _, _) => const _PreviewError(),
        ),
      ),
    ),
    NoteAttachmentPreviewKind.pdf => PdfView(controller: _pdfController!),
    NoteAttachmentPreviewKind.text => _text == null
        ? _loadError == null
              ? const Center(child: CircularProgressIndicator())
              : const _PreviewError()
        : SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: SelectableText(_text!),
          ),
    NoteAttachmentPreviewKind.external => _ExternalAttachmentInfo(
      attachment: widget.attachment,
      file: widget.file,
    ),
  };
}

class _ExternalAttachmentInfo extends StatelessWidget {
  const _ExternalAttachmentInfo({required this.attachment, required this.file});

  final NoteAttachment attachment;
  final File file;

  @override
  Widget build(BuildContext context) => Center(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 420),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.insert_drive_file_outlined, size: 48),
            const SizedBox(height: 16),
            Text(attachment.fileName, textAlign: TextAlign.center),
            const SizedBox(height: 6),
            Text(
              '${attachment.mimeType} · ${_formatBytes(attachment.byteSize)}',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 20),
            OutlinedButton.icon(
              onPressed: () => launchUrl(Uri.file(file.path)),
              icon: const Icon(Icons.open_in_new),
              label: const Text('Otwórz w aplikacji systemowej'),
            ),
          ],
        ),
      ),
    ),
  );
}

class _PreviewError extends StatelessWidget {
  const _PreviewError();

  @override
  Widget build(BuildContext context) => const Center(
    child: Text('Nie udało się wyświetlić tego pliku.'),
  );
}

String _formatBytes(int bytes) {
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
  return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
}
