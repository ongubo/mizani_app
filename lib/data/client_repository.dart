import 'package:dio/dio.dart';

import '../models/models.dart';
import 'api_client.dart';

/// Everything the app asks of the server. Screens use this, never HTTP.
abstract class ClientRepository {
  Future<OtpChallenge> requestOtp(String identifier);
  Future<AuthResult> verifyOtp({
    required String challengeId,
    required String code,
    required String deviceId,
  });
  Future<void> logout();

  Future<Invitation> invitation(String token);
  Future<OtpChallenge> requestInvitationOtp(String token);
  Future<InvitationSession> verifyInvitation({
    required String token,
    required String code,
    required String deviceId,
  });
  Future<ProposalDetail> startInvitation(String invitationId);

  Future<Client> me();
  Future<Client> updateEmail(String email);
  Future<HomeSummary> home();
  Future<void> registerDevice({
    required String deviceId,
    required String platform,
  });
  Future<void> unregisterDevice(String deviceId);

  Future<List<CoverType>> coverTypes();
  Future<List<Underwriter>> underwriters(String coverKey);
  Future<ProposalDetail> startProposal({
    required String coverKey,
    required String underwriterId,
  });
  Future<List<Proposal>> proposals();
  Future<ProposalDetail> proposal(String id);
  Future<ProposalDetail> saveAnswers(String id, Map<String, dynamic> answers);
  Future<ProposalDocument> uploadDocument(
    String id, {
    required String key,
    required String filePath,
    required String fileName,
    void Function(double progress)? onProgress,
  });
  Future<void> removeDocument(String id, String key);
  Future<ProposalDetail> submitProposal(String id);

  Future<List<Quote>> quotes(String proposalId);
  Future<PolicySummary> acceptQuote(String quoteId, {String? planKey});
  Future<void> downloadQuoteDocument({
    required String quoteId,
    required String documentId,
    required String savePath,
  });
}

class ApiClientRepository implements ClientRepository {
  ApiClientRepository(this._api);

  final ApiClient _api;

  Json _data(dynamic response) => (response as Json)['data'] as Json;
  List<Json> _rows(dynamic response) =>
      ((response as Json)['data'] as List).cast<Json>();

  @override
  Future<OtpChallenge> requestOtp(String identifier) async => OtpChallenge.fromJson(
        await _api.post('/auth/otp/request', body: {'identifier': identifier}) as Json,
      );

  @override
  Future<AuthResult> verifyOtp({
    required String challengeId,
    required String code,
    required String deviceId,
  }) async =>
      AuthResult.fromJson(
        await _api.post(
          '/auth/otp/verify',
          body: {'challenge_id': challengeId, 'code': code, 'device_id': deviceId},
        ) as Json,
      );

  @override
  Future<void> logout() => _api.post('/auth/logout');

  @override
  Future<Invitation> invitation(String token) async =>
      Invitation.fromJson(_data(await _api.get('/invitations/$token')));

  @override
  Future<OtpChallenge> requestInvitationOtp(String token) async =>
      OtpChallenge.fromJson(await _api.post('/invitations/$token/otp') as Json);

  @override
  Future<InvitationSession> verifyInvitation({
    required String token,
    required String code,
    required String deviceId,
  }) async =>
      InvitationSession.fromJson(
        await _api.post(
          '/invitations/$token/verify',
          body: {'code': code, 'device_id': deviceId},
        ) as Json,
      );

  @override
  Future<ProposalDetail> startInvitation(String invitationId) async =>
      ProposalDetail.fromJson(
        _data(await _api.post('/me/invitations/$invitationId/start')),
      );

  @override
  Future<Client> me() async => Client.fromJson(_data(await _api.get('/me')));

  @override
  Future<Client> updateEmail(String email) async =>
      Client.fromJson(_data(await _api.patch('/me', body: {'email': email})));

  @override
  Future<HomeSummary> home() async =>
      HomeSummary.fromJson(await _api.get('/home') as Json);

  @override
  Future<void> registerDevice({
    required String deviceId,
    required String platform,
  }) =>
      _api.put('/devices/$deviceId', body: {'platform': platform});

  @override
  Future<void> unregisterDevice(String deviceId) =>
      _api.delete('/devices/$deviceId');

  @override
  Future<List<CoverType>> coverTypes() async =>
      _rows(await _api.get('/cover-types')).map(CoverType.fromJson).toList();

  @override
  Future<List<Underwriter>> underwriters(String coverKey) async =>
      _rows(await _api.get('/cover-types/$coverKey/underwriters'))
          .map(Underwriter.fromJson)
          .toList();

  @override
  Future<ProposalDetail> startProposal({
    required String coverKey,
    required String underwriterId,
  }) async =>
      ProposalDetail.fromJson(
        _data(
          await _api.post(
            '/proposals',
            body: {'cover_type': coverKey, 'underwriter_id': underwriterId},
          ),
        ),
      );

  @override
  Future<List<Proposal>> proposals() async =>
      _rows(await _api.get('/proposals', query: {'per_page': 100}))
          .map(Proposal.fromJson)
          .toList();

  @override
  Future<ProposalDetail> proposal(String id) async =>
      ProposalDetail.fromJson(_data(await _api.get('/proposals/$id')));

  @override
  Future<ProposalDetail> saveAnswers(
    String id,
    Map<String, dynamic> answers,
  ) async =>
      ProposalDetail.fromJson(
        _data(await _api.patch('/proposals/$id/answers', body: {'answers': answers})),
      );

  @override
  Future<ProposalDocument> uploadDocument(
    String id, {
    required String key,
    required String filePath,
    required String fileName,
    void Function(double progress)? onProgress,
  }) async {
    final form = FormData.fromMap({
      'key': key,
      'file': await MultipartFile.fromFile(filePath, filename: fileName),
    });
    return ProposalDocument.fromJson(
      _data(
        await _api.upload(
          '/proposals/$id/documents',
          form,
          onProgress: onProgress,
        ),
      ),
    );
  }

  @override
  Future<void> removeDocument(String id, String key) =>
      _api.delete('/proposals/$id/documents/$key');

  @override
  Future<ProposalDetail> submitProposal(String id) async =>
      ProposalDetail.fromJson(_data(await _api.post('/proposals/$id/submit')));

  @override
  Future<List<Quote>> quotes(String proposalId) async =>
      _rows(await _api.get('/proposals/$proposalId/quotes'))
          .map(Quote.fromJson)
          .toList();

  @override
  Future<PolicySummary> acceptQuote(String quoteId, {String? planKey}) async =>
      PolicySummary.fromJson(
        _data(
          await _api.post(
            '/quotes/$quoteId/accept',
            body: {'payment_plan_key': planKey},
          ),
        ),
      );

  @override
  Future<void> downloadQuoteDocument({
    required String quoteId,
    required String documentId,
    required String savePath,
  }) =>
      _api.download('/quotes/$quoteId/documents/$documentId', savePath);
}
