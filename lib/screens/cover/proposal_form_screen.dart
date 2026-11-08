import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../data/api_client.dart';
import '../../data/client_repository.dart';
import '../../data/session.dart';
import '../../models/models.dart';
import '../../theme/mizani_theme.dart';
import '../../widgets/api_loader.dart';
import 'question_field.dart';

const _maxUploadBytes = 5 * 1024 * 1024;

/// An application, built entirely from the form the API sends: one step per
/// section, then documents, then review. A draft is saved after each step.
class ProposalFormScreen extends StatelessWidget {
  const ProposalFormScreen({super.key, required this.proposalId});

  final String proposalId;

  @override
  Widget build(BuildContext context) {
    final repository = context.read<SessionController>().repository;
    return Scaffold(
      appBar: AppBar(title: const Text('Your application')),
      body: SafeArea(
        child: _ProposalLoader(
          load: () => repository.proposal(proposalId),
        ),
      ),
    );
  }
}

/// Loads once and doesn't reload under the client while they are typing.
class _ProposalLoader extends StatefulWidget {
  const _ProposalLoader({required this.load});

  final Future<ProposalDetail> Function() load;

  @override
  State<_ProposalLoader> createState() => _ProposalLoaderState();
}

class _ProposalLoaderState extends State<_ProposalLoader> {
  late Future<ProposalDetail> _future = widget.load();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<ProposalDetail>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.hasData) {
          final proposal = snapshot.data!;
          if (proposal.status != ProposalStatus.draft) {
            return MessageView(
              icon: Icons.check_circle_outline,
              color: MizaniColors.ok,
              title: 'Already sent',
              body: '${proposal.partnerName} has this application.',
            );
          }
          return _ProposalForm(proposal: proposal);
        }
        if (snapshot.hasError) {
          return ErrorView(
            message: snapshot.error.toString(),
            onRetry: () => setState(() => _future = widget.load()),
          );
        }
        return const Center(child: CircularProgressIndicator());
      },
    );
  }
}

enum _StepKind { section, documents, review }

class _Step {
  const _Step(this.kind, this.title, [this.questions = const []]);

  final _StepKind kind;
  final String title;
  final List<FormQuestion> questions;
}

class _ProposalForm extends StatefulWidget {
  const _ProposalForm({required this.proposal});
  final ProposalDetail proposal;

  @override
  State<_ProposalForm> createState() => _ProposalFormState();
}

class _ProposalFormState extends State<_ProposalForm> {
  late final Map<String, dynamic> _answers = Map.of(widget.proposal.answers);
  late List<ProposalDocument> _documents = widget.proposal.documents;
  final Map<String, String> _errors = {};
  final Map<String, double> _uploading = {};

  int _step = 0;
  bool _busy = false;
  bool _sent = false;

  CoverForm get _form => widget.proposal.form;
  ClientRepository get _repository => context.read<SessionController>().repository;

  @override
  void initState() {
    super.initState();
    _step = _firstIncompleteStep();
  }

  List<_Step> get _steps {
    final visible = _form.visibleQuestions(_answers).map((q) => q.key).toSet();
    return [
      for (final section in _form.sections)
        if (section.questions.any((q) => visible.contains(q.key)))
          _Step(
            _StepKind.section,
            section.title,
            section.questions.where((q) => visible.contains(q.key)).toList(),
          ),
      if (_form.visibleDocuments(_answers).isNotEmpty) const _Step(_StepKind.documents, 'Documents'),
      const _Step(_StepKind.review, 'Review and send'),
    ];
  }

  int _firstIncompleteStep() {
    final steps = _steps;
    for (var i = 0; i < steps.length; i++) {
      final step = steps[i];
      final incomplete = switch (step.kind) {
        _StepKind.section => step.questions.any((q) => validateAnswer(q, _answers[q.key]) != null),
        _StepKind.documents => _form
            .visibleDocuments(_answers)
            .any((d) => d.required && !_documents.any((u) => u.key == d.key)),
        _StepKind.review => false,
      };
      if (incomplete) {
        return i;
      }
    }
    return steps.length - 1;
  }

  /// Every question goes up, with blanks as null, so a cleared answer is
  /// removed. The server keeps only the ones that are showing.
  Map<String, dynamic> get _payload => {
        for (final question in _form.questions)
          question.key: switch (_answers[question.key]) {
            final String text => text.trim().isEmpty ? null : text.trim(),
            final other => other,
          },
      };

  bool _validate(_Step step) {
    _errors.clear();
    if (step.kind == _StepKind.section) {
      for (final question in step.questions) {
        final error = validateAnswer(question, _answers[question.key]);
        if (error != null) {
          _errors['answers.${question.key}'] = error;
        }
      }
    }
    if (step.kind == _StepKind.documents) {
      for (final document in _form.visibleDocuments(_answers)) {
        if (document.required && !_documents.any((u) => u.key == document.key)) {
          _errors['uploads.${document.key}'] = 'Upload your ${document.label}.';
        }
      }
    }
    setState(() {});
    return _errors.isEmpty;
  }

  Future<void> _next() async {
    final steps = _steps;
    final step = steps[_clampedStep(steps)];
    if (!_validate(step)) {
      return;
    }
    await _run(() async {
      await _repository.saveAnswers(widget.proposal.id, _payload);
      if (!mounted) return;
      setState(() => _step = _clampedStep(steps) + 1);
    });
  }

  void _back() {
    setState(() {
      _errors.clear();
      _step = _clampedStep(_steps) - 1;
    });
  }

  Future<void> _submit() async {
    final session = context.read<SessionController>();
    setState(() => _busy = true);
    try {
      await session.repository.saveAnswers(widget.proposal.id, _payload);
      await session.repository.submitProposal(widget.proposal.id);
      session.dataChanged();
      if (mounted) setState(() => _sent = true);
    } on ApiException catch (e) {
      if (!mounted) return;
      if (e.fieldErrors.isNotEmpty) {
        setState(() {
          _errors
            ..clear()
            ..addAll(e.fieldErrors);
          _step = _stepHolding(e.fieldErrors.keys.first);
        });
      }
      showMessage(context, e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  int _stepHolding(String field) {
    final steps = _steps;
    for (var i = 0; i < steps.length; i++) {
      if (steps[i].kind == _StepKind.documents && field.startsWith('uploads.')) {
        return i;
      }
      if (steps[i].questions.any((q) => 'answers.${q.key}' == field)) {
        return i;
      }
    }
    return 0;
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() => _busy = true);
    try {
      await action();
    } on ApiException catch (e) {
      if (mounted) showMessage(context, e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  int _clampedStep(List<_Step> steps) => _step.clamp(0, steps.length - 1);

  Future<void> _chooseFile(FormDocument document) async {
    final source = await showModalBottomSheet<_UploadSource>(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Take a photo'),
              onTap: () => Navigator.of(context).pop(_UploadSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choose from gallery'),
              onTap: () => Navigator.of(context).pop(_UploadSource.gallery),
            ),
            ListTile(
              leading: const Icon(Icons.description_outlined),
              title: const Text('Choose a file'),
              onTap: () => Navigator.of(context).pop(_UploadSource.file),
            ),
          ],
        ),
      ),
    );
    if (source == null) return;

    final picked = await _pick(source);
    if (picked == null || !mounted) return;

    if (await File(picked.path).length() > _maxUploadBytes) {
      if (mounted) {
        setState(() => _errors['uploads.${document.key}'] = 'The file must be 5 MB or smaller.');
      }
      return;
    }

    await _upload(document, picked);
  }

  Future<_PickedFile?> _pick(_UploadSource source) async {
    if (source == _UploadSource.file) {
      final files = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['pdf', 'jpg', 'jpeg', 'png'],
      );
      final file = files.firstOrNull;
      return file?.path == null ? null : _PickedFile(file!.path!, file.name);
    }

    final image = await ImagePicker().pickImage(
      source: source == _UploadSource.camera ? ImageSource.camera : ImageSource.gallery,
      maxWidth: 1800,
      imageQuality: 75,
    );
    return image == null ? null : _PickedFile(image.path, image.name);
  }

  Future<void> _upload(FormDocument document, _PickedFile file) async {
    final repository = _repository;
    setState(() {
      _errors.remove('uploads.${document.key}');
      _uploading[document.key] = 0;
    });
    try {
      // The server checks the document against saved answers.
      await repository.saveAnswers(widget.proposal.id, _payload);
      final uploaded = await repository.uploadDocument(
        widget.proposal.id,
        key: document.key,
        filePath: file.path,
        fileName: file.name,
        onProgress: (progress) {
          if (mounted) setState(() => _uploading[document.key] = progress);
        },
      );
      if (mounted) {
        setState(() {
          _documents = [..._documents.where((d) => d.key != document.key), uploaded];
        });
      }
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          _errors['uploads.${document.key}'] = e.fieldErrors['file'] ?? e.message;
        });
      }
    } finally {
      if (mounted) setState(() => _uploading.remove(document.key));
    }
  }

  Future<void> _remove(FormDocument document) => _run(() async {
        await _repository.removeDocument(widget.proposal.id, document.key);
        if (mounted) {
          setState(() {
            _documents = _documents.where((d) => d.key != document.key).toList();
          });
        }
      });

  @override
  Widget build(BuildContext context) {
    if (_sent) {
      return MessageView(
        icon: Icons.check_circle_outline,
        color: MizaniColors.ok,
        title: 'Application sent',
        body: '${widget.proposal.partnerName} has your details. Your quotes will appear in the app when they are ready.',
        action: ElevatedButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Done'),
        ),
      );
    }

    final steps = _steps;
    final index = _clampedStep(steps);
    final step = steps[index];

    return Column(
      children: [
        LinearProgressIndicator(value: (index + 1) / steps.length),
        Expanded(
          child: ListView(
            key: ValueKey('step-$index-${step.title}'),
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            children: [
              Text(
                'Step ${index + 1} of ${steps.length} · ${widget.proposal.coverType.name}',
                style: const TextStyle(fontSize: 12, color: MizaniColors.muted),
              ),
              const SizedBox(height: 4),
              Text(step.title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
              const SizedBox(height: 16),
              ...switch (step.kind) {
                _StepKind.section => _questions(step),
                _StepKind.documents => _documentRows(),
                _StepKind.review => _review(),
              },
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
          child: Row(
            children: [
              if (index > 0) ...[
                Expanded(
                  child: OutlinedButton(onPressed: _busy ? null : _back, child: const Text('Back')),
                ),
                const SizedBox(width: 12),
              ],
              Expanded(
                child: step.kind == _StepKind.review
                    ? ElevatedButton(
                        onPressed: _busy ? null : _submit,
                        child: Text(_busy ? 'Sending…' : 'Send application'),
                      )
                    : ElevatedButton(
                        onPressed: _busy || _uploading.isNotEmpty ? null : _next,
                        child: Text(_busy ? 'Saving…' : 'Next'),
                      ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  List<Widget> _questions(_Step step) => [
        for (final question in step.questions)
          Padding(
            key: ValueKey(question.key),
            padding: const EdgeInsets.only(bottom: 14),
            child: QuestionField(
              question: question,
              value: _answers[question.key],
              errorText: _errors['answers.${question.key}'],
              onChanged: (value) => setState(() {
                _answers[question.key] = value;
                _errors.remove('answers.${question.key}');
              }),
            ),
          ),
      ];

  List<Widget> _documentRows() => [
        for (final document in _form.visibleDocuments(_answers)) _documentRow(document),
      ];

  Widget _documentRow(FormDocument document) {
    final uploaded = _documents.where((d) => d.key == document.key).firstOrNull;
    final progress = _uploading[document.key];
    final error = _errors['uploads.${document.key}'];

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              document.required ? document.label : '${document.label} (optional)',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            if (uploaded != null) ...[
              const SizedBox(height: 4),
              Text(uploaded.fileName, style: const TextStyle(fontSize: 12, color: MizaniColors.ok)),
            ],
            if (error != null) ...[
              const SizedBox(height: 4),
              Text(error, style: const TextStyle(fontSize: 12, color: MizaniColors.bad)),
            ],
            const SizedBox(height: 8),
            if (progress != null)
              LinearProgressIndicator(value: progress)
            else
              Row(
                children: [
                  TextButton.icon(
                    icon: const Icon(Icons.upload_file, size: 18),
                    label: Text(uploaded == null ? 'Upload' : 'Replace'),
                    onPressed: _busy ? null : () => _chooseFile(document),
                  ),
                  if (uploaded != null)
                    TextButton(
                      onPressed: _busy ? null : () => _remove(document),
                      child: const Text('Remove', style: TextStyle(color: MizaniColors.bad)),
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  List<Widget> _review() {
    final questions = _form.visibleQuestions(_answers).where((q) => _hasAnswer(q.key));
    final documents = _form
        .visibleDocuments(_answers)
        .where((d) => _documents.any((u) => u.key == d.key));
    return [
      Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final question in questions)
                _reviewRow(question.label, _reviewValue(_answers[question.key])),
              for (final document in documents)
                _reviewRow(document.label, _documents.firstWhere((u) => u.key == document.key).fileName),
            ],
          ),
        ),
      ),
    ];
  }

  bool _hasAnswer(String key) {
    final value = _answers[key];
    return value != null && value != '' && !(value is List && value.isEmpty);
  }

  String _reviewValue(Object? value) => switch (value) {
        true => 'Yes',
        false => 'No',
        final List<dynamic> list => list.join(', '),
        _ => value.toString(),
      };

  Widget _reviewRow(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(fontSize: 12, color: MizaniColors.muted)),
            Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
          ],
        ),
      );
}

enum _UploadSource { camera, gallery, file }

class _PickedFile {
  const _PickedFile(this.path, this.name);

  final String path;
  final String name;
}
