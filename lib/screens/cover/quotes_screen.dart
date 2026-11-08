import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';

import '../../data/api_client.dart';
import '../../data/session.dart';
import '../../models/models.dart';
import '../../theme/mizani_theme.dart';
import '../../widgets/api_loader.dart';

/// The quotes shared on an application, lowest premium first.
class QuotesScreen extends StatelessWidget {
  const QuotesScreen({super.key, required this.proposalId, required this.coverName});

  final String proposalId;
  final String coverName;

  @override
  Widget build(BuildContext context) {
    final repository = context.read<SessionController>().repository;
    return Scaffold(
      appBar: AppBar(title: Text(coverName)),
      body: ApiLoader<List<Quote>>(
        load: () => repository.quotes(proposalId),
        builder: (context, quotes, reload) {
          if (quotes.isEmpty) {
            return const MessageView(
              icon: Icons.hourglass_empty,
              color: MizaniColors.muted,
              title: 'No quotes yet',
              body: "We'll let you know as soon as they are ready.",
            );
          }
          final hasAccepted = quotes.any((quote) => quote.isAccepted);
          return RefreshIndicator(
            onRefresh: reload,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              children: [
                for (final (index, quote) in quotes.indexed)
                  _QuoteCard(
                    quote: quote,
                    isLowest: index == 0 && quotes.length > 1 && !hasAccepted,
                    onChanged: reload,
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _QuoteCard extends StatefulWidget {
  const _QuoteCard({required this.quote, required this.isLowest, required this.onChanged});

  final Quote quote;
  final bool isLowest;
  final Future<void> Function() onChanged;

  @override
  State<_QuoteCard> createState() => _QuoteCardState();
}

class _QuoteCardState extends State<_QuoteCard> {
  late String? _planKey = widget.quote.plans.firstOrNull?.key;
  bool _accepting = false;
  String? _openingDocument;

  Quote get _quote => widget.quote;

  Future<void> _accept() async {
    final amount = formatMoney(_quote.premium, currency: _quote.currency);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: const Text('Accept this quote?'),
        content: Text('$amount with ${_quote.underwriterName}. Your other quotes will be closed.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialog).pop(false), child: const Text('Not yet')),
          TextButton(onPressed: () => Navigator.of(dialog).pop(true), child: const Text('Accept')),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _accepting = true);
    final session = context.read<SessionController>();
    try {
      final policy = await session.repository.acceptQuote(_quote.id, planKey: _planKey);
      if (!mounted) return;
      await Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => _AcceptedScreen(policy: policy)),
      );
      session.dataChanged();
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _accepting = false);
      showMessage(context, e.message);
      if (e.statusCode == 409 || e.code == 'quote_expired') {
        await widget.onChanged();
      }
    }
  }

  Future<void> _openDocument(QuoteDocument document) async {
    setState(() => _openingDocument = document.id);
    final repository = context.read<SessionController>().repository;
    try {
      final directory = await getTemporaryDirectory();
      final extension = document.fileName.contains('.') ? document.fileName.split('.').last : 'pdf';
      final path = '${directory.path}/${document.id}.$extension';
      await repository.downloadQuoteDocument(
        quoteId: _quote.id,
        documentId: document.id,
        savePath: path,
      );
      final result = await OpenFilex.open(path);
      if (result.type != ResultType.done && mounted) {
        showMessage(context, 'No app on this phone can open that file.');
      }
    } on ApiException catch (e) {
      if (mounted) showMessage(context, e.message);
    } finally {
      if (mounted) setState(() => _openingDocument = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final quote = _quote;
    final canAccept = !quote.isAccepted && !quote.expired;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    quote.underwriterName,
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                  ),
                ),
                if (quote.isAccepted)
                  const _Tag('Accepted', MizaniColors.ok, MizaniColors.okSoft)
                else if (quote.expired)
                  const _Tag('Expired', MizaniColors.bad, MizaniColors.badSoft)
                else if (widget.isLowest)
                  const _Tag('Lowest', MizaniColors.info, MizaniColors.infoSoft),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              formatMoney(quote.premium, currency: quote.currency),
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
            ),
            Text(
              [
                'Quote ${quote.quotationNumber}',
                if (quote.validUntil != null) 'valid until ${formatDate(quote.validUntil!)}',
              ].join(' · '),
              style: const TextStyle(fontSize: 12, color: MizaniColors.muted),
            ),
            if (quote.accountNumber != null) ...[
              const SizedBox(height: 12),
              _AccountNumber(quote.accountNumber!),
            ],
            if (quote.lines.length > 1) ...[
              const SizedBox(height: 12),
              for (final line in quote.lines)
                _Row(line.label, formatMoney(line.amount, currency: quote.currency)),
            ],
            if (quote.terms != null) ...[
              const SizedBox(height: 12),
              Text(quote.terms!, style: const TextStyle(fontSize: 13)),
            ],
            if (quote.documents.isNotEmpty) ...[
              const SizedBox(height: 12),
              const Text('Documents', style: TextStyle(fontWeight: FontWeight.w600)),
              for (final document in quote.documents)
                ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.description_outlined, size: 20),
                  title: Text(document.title),
                  trailing: _openingDocument == document.id
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.download_outlined, size: 20),
                  onTap: _openingDocument == null ? () => _openDocument(document) : null,
                ),
            ],
            if (canAccept && quote.plans.isNotEmpty) ...[
              const SizedBox(height: 12),
              const Text('Payment plan', style: TextStyle(fontWeight: FontWeight.w600)),
              RadioGroup<String>(
                groupValue: _planKey,
                onChanged: (key) => setState(() => _planKey = key),
                child: Column(
                  children: [
                    for (final plan in quote.plans)
                      RadioListTile<String>(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        value: plan.key,
                        title: Text(plan.label),
                        subtitle: Text(plan.splitsLabel),
                      ),
                  ],
                ),
              ),
            ],
            if (canAccept) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _accepting ? null : _accept,
                  child: Text(_accepting ? 'Accepting…' : 'Accept this quote'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _AcceptedScreen extends StatelessWidget {
  const _AcceptedScreen({required this.policy});

  final PolicySummary policy;

  @override
  Widget build(BuildContext context) {
    final plan = policy.paymentPlan;
    return Scaffold(
      appBar: AppBar(title: const Text('Quote accepted')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Icon(Icons.check_circle_outline, color: MizaniColors.ok, size: 48),
          const SizedBox(height: 12),
          Text(
            'You chose ${policy.underwriterName}',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(
            policy.coverType.name,
            textAlign: TextAlign.center,
            style: const TextStyle(color: MizaniColors.muted),
          ),
          const SizedBox(height: 20),
          _AccountNumber(policy.accountNumber),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                children: [
                  _Row('Premium', formatMoney(policy.premium, currency: policy.currency)),
                  if (plan != null) ...[
                    _Row('Payment plan', plan.label),
                    _Row('Instalments', plan.splitsLabel),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Quote this account number whenever you pay. We have emailed you these details.',
            textAlign: TextAlign.center,
            style: TextStyle(color: MizaniColors.muted, fontSize: 13),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }
}

class _AccountNumber extends StatelessWidget {
  const _AccountNumber(this.number);
  final String number;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: MizaniColors.okSoft, borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Account number', style: TextStyle(fontSize: 12, color: MizaniColors.muted)),
          const SizedBox(height: 2),
          SelectableText(
            number,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, letterSpacing: 1),
          ),
        ],
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag(this.label, this.color, this.soft);
  final String label;
  final Color color;
  final Color soft;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: soft, borderRadius: BorderRadius.circular(999)),
      child: Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color)),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row(this.label, this.value);
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: MizaniColors.muted, fontSize: 13)),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
