import 'dart:io';

import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdfx/pdfx.dart';

import '../data/api_client.dart';
import '../theme/mizani_theme.dart';
import 'api_loader.dart';

const _imageExtensions = {'jpg', 'jpeg', 'png'};

String _extensionOf(String fileName) {
  final extension = fileName.contains('.') ? fileName.split('.').last.toLowerCase() : '';
  return RegExp(r'^[a-z0-9]{1,8}$').hasMatch(extension) ? extension : 'bin';
}

/// Fetches a file and shows pictures and PDFs inside the app. Anything else
/// goes to whichever app on the phone can open it.
Future<void> openDocument(
  BuildContext context, {
  required String title,
  required String fileName,
  required Future<void> Function(String savePath) download,
}) async {
  final extension = _extensionOf(fileName);
  try {
    final directory = await getTemporaryDirectory();
    final path = '${directory.path}/doc_${DateTime.now().microsecondsSinceEpoch}.$extension';
    await download(path);
    if (!context.mounted) return;

    if (extension == 'pdf' || _imageExtensions.contains(extension)) {
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => _DocumentViewerScreen(title: title, path: path, isPdf: extension == 'pdf'),
        ),
      );
      return;
    }

    final result = await OpenFilex.open(path);
    if (result.type != ResultType.done && context.mounted) {
      showMessage(context, 'No app on this phone can open that file.');
    }
  } on ApiException catch (e) {
    if (context.mounted) showMessage(context, e.message);
  }
}

class _DocumentViewerScreen extends StatefulWidget {
  const _DocumentViewerScreen({required this.title, required this.path, required this.isPdf});

  final String title;
  final String path;
  final bool isPdf;

  @override
  State<_DocumentViewerScreen> createState() => _DocumentViewerScreenState();
}

class _DocumentViewerScreenState extends State<_DocumentViewerScreen> {
  PdfControllerPinch? _pdf;

  @override
  void initState() {
    super.initState();
    if (widget.isPdf) {
      _pdf = PdfControllerPinch(document: PdfDocument.openFile(widget.path));
    }
  }

  @override
  void dispose() {
    _pdf?.dispose();
    // These are personal documents, so no copy stays behind on the phone.
    File(widget.path).delete().ignore();
    super.dispose();
  }

  Widget _unreadable() => const MessageView(
        icon: Icons.broken_image_outlined,
        color: MizaniColors.muted,
        title: "We can't show this file",
        body: 'It may be damaged. Try opening it in another app.',
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
          IconButton(
            tooltip: 'Open in another app',
            icon: const Icon(Icons.open_in_new),
            onPressed: () => OpenFilex.open(widget.path),
          ),
        ],
      ),
      body: SafeArea(
        child: widget.isPdf
            ? PdfViewPinch(
                controller: _pdf!,
                builders: PdfViewPinchBuilders<DefaultBuilderOptions>(
                  options: const DefaultBuilderOptions(),
                  errorBuilder: (_, _) => _unreadable(),
                ),
              )
            : InteractiveViewer(
                maxScale: 5,
                child: Center(
                  child: Image.file(
                    File(widget.path),
                    errorBuilder: (_, _, _) => _unreadable(),
                  ),
                ),
              ),
      ),
    );
  }
}
