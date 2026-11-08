/// Models for the client API under `/api/v1/client`. Each mirrors a Laravel
/// API resource in `mizani_web/app/Http/Resources/V1/Client`.
library;

typedef Json = Map<String, dynamic>;

DateTime? _date(Object? value) =>
    value == null ? null : DateTime.parse(value as String).toLocal();

List<T> _list<T>(Object? value, T Function(Json) parse) =>
    ((value as List?) ?? const [])
        .map((item) => parse(item as Json))
        .toList();

class Client {
  const Client({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.name,
    this.middleName,
    this.phone,
    this.email,
    this.nationalId,
    this.kraPin,
  });

  factory Client.fromJson(Json json) => Client(
        id: json['id'] as String,
        firstName: (json['first_name'] as String?) ?? '',
        middleName: json['middle_name'] as String?,
        lastName: (json['last_name'] as String?) ?? '',
        name: (json['name'] as String?) ?? '',
        phone: json['phone'] as String?,
        email: json['email'] as String?,
        nationalId: json['national_id'] as String?,
        kraPin: json['kra_pin'] as String?,
      );

  final String id;
  final String firstName;
  final String? middleName;
  final String lastName;
  final String name;
  final String? phone;
  final String? email;
  final String? nationalId;
  final String? kraPin;
}

class OtpChallenge {
  const OtpChallenge({
    required this.maskedPhone,
    required this.channel,
    required this.resendAfter,
    this.challengeId,
  });

  factory OtpChallenge.fromJson(Json json) => OtpChallenge(
        challengeId: json['challenge_id'] as String?,
        maskedPhone: (json['masked_phone'] as String?) ?? '',
        channel: (json['channel'] as String?) ?? 'email',
        resendAfter: (json['resend_after'] as num?)?.toInt() ?? 30,
      );

  /// Only sign-in has one. An invitation code is tied to its link.
  final String? challengeId;
  final String maskedPhone;
  final String channel;
  final int resendAfter;
}

class AuthResult {
  const AuthResult({required this.token, required this.client});

  factory AuthResult.fromJson(Json json) => AuthResult(
        token: json['token'] as String,
        client: Client.fromJson(json['client'] as Json),
      );

  final String token;
  final Client client;
}

class InvitationSession {
  const InvitationSession({required this.auth, required this.proposal});

  factory InvitationSession.fromJson(Json json) => InvitationSession(
        auth: AuthResult.fromJson(json),
        proposal: ProposalDetail.fromJson(json['proposal'] as Json),
      );

  final AuthResult auth;
  final ProposalDetail proposal;
}

class CoverType {
  const CoverType({
    required this.key,
    required this.name,
    this.icon,
    this.requiresValuation = false,
  });

  factory CoverType.fromJson(Json json) => CoverType(
        key: json['key'] as String,
        name: json['name'] as String,
        icon: json['icon'] as String?,
        requiresValuation: (json['requires_valuation'] as bool?) ?? false,
      );

  final String key;
  final String name;
  final String? icon;
  final bool requiresValuation;
}

class Underwriter {
  const Underwriter({
    required this.id,
    required this.name,
    required this.quoteMode,
  });

  factory Underwriter.fromJson(Json json) => Underwriter(
        id: json['id'] as String,
        name: json['name'] as String,
        quoteMode: (json['quote_mode'] as String?) ?? '',
      );

  final String id;
  final String name;
  final String quoteMode;
}

class Invitation {
  const Invitation({
    required this.id,
    required this.status,
    required this.partnerName,
    required this.coverType,
    required this.expiresAt,
    this.maskedPhone,
  });

  factory Invitation.fromJson(Json json) => Invitation(
        id: json['id'] as String,
        status: json['status'] as String,
        partnerName: (json['partner'] as Json)['name'] as String,
        coverType: CoverType.fromJson(json['cover_type'] as Json),
        expiresAt: _date(json['expires_at'])!,
        maskedPhone: json['masked_phone'] as String?,
      );

  final String id;
  final String status;
  final String partnerName;
  final CoverType coverType;
  final DateTime expiresAt;
  final String? maskedPhone;

  bool get isSubmitted => status == 'submitted';
  bool get isOpen =>
      (status == 'sent' || status == 'verified') &&
      expiresAt.isAfter(DateTime.now());
}

enum ProposalStatus { draft, submitted, quoting, quotesShared, accepted, declined, unknown }

ProposalStatus _proposalStatus(String value) => switch (value) {
      'draft' => ProposalStatus.draft,
      'submitted' => ProposalStatus.submitted,
      'quoting' => ProposalStatus.quoting,
      'quotes_shared' => ProposalStatus.quotesShared,
      'accepted' => ProposalStatus.accepted,
      'declined' => ProposalStatus.declined,
      _ => ProposalStatus.unknown,
    };

class Proposal {
  const Proposal({
    required this.id,
    required this.status,
    required this.statusLabel,
    required this.coverType,
    required this.partnerName,
    required this.channel,
    this.submittedAt,
  });

  factory Proposal.fromJson(Json json) => Proposal(
        id: json['id'] as String,
        status: _proposalStatus(json['status'] as String),
        statusLabel: json['status_label'] as String,
        coverType: CoverType.fromJson(json['cover_type'] as Json),
        partnerName: (json['partner'] as Json)['name'] as String,
        channel: json['channel'] as String,
        submittedAt: _date(json['submitted_at']),
      );

  final String id;
  final ProposalStatus status;
  final String statusLabel;
  final CoverType coverType;
  final String partnerName;
  final String channel;
  final DateTime? submittedAt;
}

class ProposalDetail extends Proposal {
  ProposalDetail.fromJson(Json json)
      : answers = Map<String, dynamic>.of(json['answers'] as Json? ?? const {}),
        form = CoverForm.fromJson(json['form'] as Json),
        documents = _list(json['documents'], ProposalDocument.fromJson),
        super(
          id: json['id'] as String,
          status: _proposalStatus(json['status'] as String),
          statusLabel: json['status_label'] as String,
          coverType: CoverType.fromJson(json['cover_type'] as Json),
          partnerName: (json['partner'] as Json)['name'] as String,
          channel: json['channel'] as String,
          submittedAt: _date(json['submitted_at']),
        );

  final Map<String, dynamic> answers;
  final CoverForm form;
  final List<ProposalDocument> documents;
}

class ProposalDocument {
  const ProposalDocument({
    required this.key,
    required this.title,
    required this.fileName,
  });

  factory ProposalDocument.fromJson(Json json) => ProposalDocument(
        key: json['key'] as String,
        title: json['title'] as String,
        fileName: (json['file_name'] as String?) ?? '',
      );

  final String key;
  final String title;
  final String fileName;
}

class VisibleIf {
  const VisibleIf({required this.question, required this.equals});

  static VisibleIf? fromJson(Json? json) => json == null
      ? null
      : VisibleIf(question: json['question'] as String, equals: json['equals']);

  final String question;
  final Object? equals;
}

class FormQuestion {
  const FormQuestion({
    required this.key,
    required this.label,
    required this.type,
    required this.required,
    this.options = const [],
    this.visibleIf,
  });

  factory FormQuestion.fromJson(Json json) => FormQuestion(
        key: json['key'] as String,
        label: json['label'] as String,
        type: json['type'] as String,
        required: (json['required'] as bool?) ?? false,
        options: ((json['options'] as List?) ?? const [])
            .map((option) => option.toString())
            .toList(),
        visibleIf: VisibleIf.fromJson(json['visible_if'] as Json?),
      );

  final String key;
  final String label;
  final String type;
  final bool required;
  final List<String> options;
  final VisibleIf? visibleIf;
}

class FormSection {
  const FormSection({required this.title, required this.questions});

  factory FormSection.fromJson(Json json) => FormSection(
        title: json['title'] as String,
        questions: _list(json['questions'], FormQuestion.fromJson),
      );

  final String title;
  final List<FormQuestion> questions;
}

class FormDocument {
  const FormDocument({
    required this.key,
    required this.label,
    required this.required,
    this.visibleIf,
  });

  factory FormDocument.fromJson(Json json) => FormDocument(
        key: json['key'] as String,
        label: json['label'] as String,
        required: (json['required'] as bool?) ?? false,
        visibleIf: VisibleIf.fromJson(json['visible_if'] as Json?),
      );

  final String key;
  final String label;
  final bool required;
  final VisibleIf? visibleIf;
}

class CoverForm {
  const CoverForm({
    required this.version,
    required this.sections,
    required this.documents,
  });

  factory CoverForm.fromJson(Json json) => CoverForm(
        version: (json['version'] as num).toInt(),
        sections: _list(json['sections'], FormSection.fromJson),
        documents: _list(json['documents'], FormDocument.fromJson),
      );

  final int version;
  final List<FormSection> sections;
  final List<FormDocument> documents;

  List<FormQuestion> get questions =>
      sections.expand((section) => section.questions).toList();

  /// Questions showing for these answers, matching ProposalService on the
  /// server: a question that depends on a hidden question is hidden too.
  List<FormQuestion> visibleQuestions(Map<String, dynamic> answers) {
    var visible = questions;
    while (true) {
      final keys = visible.map((question) => question.key).toSet();
      final next = visible
          .where((question) => _met(question.visibleIf, answers, keys))
          .toList();
      if (next.length == visible.length) {
        return next;
      }
      visible = next;
    }
  }

  List<FormDocument> visibleDocuments(Map<String, dynamic> answers) {
    final keys = visibleQuestions(answers).map((q) => q.key).toSet();
    return documents.where((d) => _met(d.visibleIf, answers, keys)).toList();
  }

  bool _met(
    VisibleIf? condition,
    Map<String, dynamic> answers,
    Set<String> visibleKeys,
  ) =>
      condition == null ||
      (visibleKeys.contains(condition.question) &&
          answers[condition.question] == condition.equals);
}

class QuoteLine {
  const QuoteLine({required this.label, required this.amount});

  factory QuoteLine.fromJson(Json json) => QuoteLine(
        label: json['label'] as String,
        amount: num.parse(json['amount'].toString()),
      );

  final String label;
  final num amount;
}

class PaymentPlan {
  const PaymentPlan({
    required this.key,
    required this.label,
    required this.splits,
  });

  factory PaymentPlan.fromJson(Json json) => PaymentPlan(
        key: json['key'] as String,
        label: json['label'] as String,
        splits: ((json['splits'] as List?) ?? const [])
            .map((split) => (split as num).toInt())
            .toList(),
      );

  final String key;
  final String label;
  final List<int> splits;

  String get splitsLabel => splits.map((split) => '$split%').join(' / ');
}

class QuoteDocument {
  const QuoteDocument({
    required this.id,
    required this.title,
    required this.fileName,
  });

  factory QuoteDocument.fromJson(Json json) => QuoteDocument(
        id: json['id'] as String,
        title: json['title'] as String,
        fileName: (json['file_name'] as String?) ?? '',
      );

  final String id;
  final String title;
  final String fileName;
}

class Quote {
  const Quote({
    required this.id,
    required this.quotationNumber,
    required this.underwriterName,
    required this.premium,
    required this.currency,
    required this.lines,
    required this.plans,
    required this.status,
    required this.expired,
    required this.documents,
    this.terms,
    this.accountNumber,
    this.validUntil,
  });

  factory Quote.fromJson(Json json) => Quote(
        id: json['id'] as String,
        quotationNumber: json['quotation_number'] as String,
        underwriterName: (json['underwriter'] as Json)['name'] as String,
        premium: json['premium'] as num,
        currency: (json['currency'] as String?) ?? 'KES',
        lines: _list(json['lines'], QuoteLine.fromJson),
        plans: _list(json['plans'], PaymentPlan.fromJson),
        terms: json['terms'] as String?,
        status: json['status'] as String,
        accountNumber: json['account_number'] as String?,
        validUntil: _date(json['valid_until']),
        expired: (json['expired'] as bool?) ?? false,
        documents: _list(json['documents'], QuoteDocument.fromJson),
      );

  final String id;
  final String quotationNumber;
  final String underwriterName;
  final num premium;
  final String currency;
  final List<QuoteLine> lines;
  final List<PaymentPlan> plans;
  final String? terms;
  final String status;
  final String? accountNumber;
  final DateTime? validUntil;
  final bool expired;
  final List<QuoteDocument> documents;

  bool get isAccepted => status == 'accepted';
}

class PolicySummary {
  const PolicySummary({
    required this.id,
    required this.status,
    required this.accountNumber,
    required this.underwriterName,
    required this.coverType,
    required this.premium,
    required this.currency,
    this.paymentPlan,
  });

  factory PolicySummary.fromJson(Json json) => PolicySummary(
        id: json['id'] as String,
        status: json['status'] as String,
        accountNumber: json['account_number'] as String,
        underwriterName: (json['underwriter'] as Json)['name'] as String,
        coverType: CoverType.fromJson(json['cover_type'] as Json),
        premium: json['premium'] as num,
        currency: (json['currency'] as String?) ?? 'KES',
        paymentPlan: json['payment_plan'] == null
            ? null
            : PaymentPlan.fromJson(json['payment_plan'] as Json),
      );

  final String id;
  final String status;
  final String accountNumber;
  final String underwriterName;
  final CoverType coverType;
  final num premium;
  final String currency;
  final PaymentPlan? paymentPlan;
}

class HomeSummary {
  const HomeSummary({
    required this.client,
    required this.openInvitations,
    required this.openProposals,
    required this.quotesReady,
  });

  factory HomeSummary.fromJson(Json json) => HomeSummary(
        client: Client.fromJson(json['client'] as Json),
        openInvitations: _list(json['open_invitations'], Invitation.fromJson),
        openProposals: _list(json['open_proposals'], Proposal.fromJson),
        quotesReady: (json['quotes_ready'] as num?)?.toInt() ?? 0,
      );

  final Client client;
  final List<Invitation> openInvitations;
  final List<Proposal> openProposals;
  final int quotesReady;
}
