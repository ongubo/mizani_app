import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mizani_app/data/api_client.dart';
import 'package:mizani_app/data/client_repository.dart';
import 'package:mizani_app/data/session.dart';
import 'package:mizani_app/data/session_store.dart';
import 'package:mizani_app/main.dart';
import 'package:mizani_app/models/models.dart';
import 'package:mizani_app/screens/auth/login_screen.dart';

/// Answers each request with a canned status and JSON body.
class _StubAdapter implements HttpClientAdapter {
  _StubAdapter(this.respond);

  final (int, Object?) Function(RequestOptions) respond;
  final requests = <RequestOptions>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    final (status, body) = respond(options);
    return ResponseBody.fromString(
      jsonEncode(body),
      status,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

class _MemoryStore implements SessionStore {
  String? token;

  @override
  Future<String?> readToken() async => token;

  @override
  Future<void> writeToken(String value) async => token = value;

  @override
  Future<void> clearToken() async => token = null;

  @override
  Future<String> deviceId() async => 'device-1';
}

(ApiClient, ApiClientRepository, _StubAdapter) _repository((int, Object?) Function(RequestOptions) respond) {
  final adapter = _StubAdapter(respond);
  final api = ApiClient(dio: Dio()..httpClientAdapter = adapter, baseUrl: 'http://test');
  return (api, ApiClientRepository(api), adapter);
}

CoverForm _form() => CoverForm.fromJson({
      'version': 1,
      'sections': [
        {
          'title': 'Cover',
          'questions': [
            {'key': 'has_dependants', 'label': 'Dependants?', 'type': 'boolean', 'required': true, 'options': null, 'visible_if': null},
            {
              'key': 'dependant_count',
              'label': 'How many?',
              'type': 'number',
              'required': true,
              'options': null,
              'visible_if': {'question': 'has_dependants', 'equals': true},
            },
            {
              'key': 'dependant_school',
              'label': 'School?',
              'type': 'text',
              'required': false,
              'options': null,
              'visible_if': {'question': 'dependant_count', 'equals': 2},
            },
          ],
        },
      ],
      'documents': [
        {
          'key': 'birth_certificate',
          'label': 'Birth certificate',
          'required': true,
          'visible_if': {'question': 'has_dependants', 'equals': true},
        },
      ],
    });

void main() {
  group('sign-in', () {
    test('a good code stores the token, registers the device and signs in', () async {
      final (api, repository, adapter) = _repository((options) {
        if (options.path.endsWith('/auth/otp/verify')) {
          return (
            200,
            {
              'token': 'abc',
              'expires_at': '2027-01-01T00:00:00+03:00',
              'client': {'id': 'c1', 'first_name': 'Amani', 'last_name': 'Otieno', 'name': 'Amani Otieno'},
            },
          );
        }
        return (200, {'device_id': 'device-1'});
      });
      final store = _MemoryStore();
      final session = SessionController(api: api, repository: repository, store: store);

      await session.verifyCode('challenge', '123456');

      expect(store.token, 'abc');
      expect(session.client.firstName, 'Amani');
      expect(adapter.requests.last.path, '/devices/device-1');
      expect(adapter.requests.last.headers['Authorization'], 'Bearer abc');
    });

    test('an expired token ends the session', () async {
      final (api, repository, _) = _repository((_) => (401, {'message': 'Unauthenticated.'}));
      final store = _MemoryStore()..token = 'old';
      final session = SessionController(api: api, repository: repository, store: store);

      expect(await session.restore(), isFalse);
      expect(store.token, isNull);
    });

    test('a network failure at launch keeps the saved sign-in', () async {
      final adapter = _ThrowingAdapter();
      final api = ApiClient(dio: Dio()..httpClientAdapter = adapter, baseUrl: 'http://test');
      final store = _MemoryStore()..token = 'keep';
      final session = SessionController(api: api, repository: ApiClientRepository(api), store: store);

      await expectLater(session.restore(), throwsA(isA<ApiException>()));
      expect(store.token, 'keep');
    });

    test('reads the token from a pasted invitation link', () {
      expect(invitationTokenFrom('https://mizani.test/i/AbC123'), 'AbC123');
      expect(invitationTokenFrom(' AbC123 '), 'AbC123');
      expect(invitationTokenFrom('not a link!'), isNull);
    });
  });

  group('errors', () {
    test('validation errors come back by field', () async {
      final (_, repository, _) = _repository(
        (_) => (
          422,
          {
            'message': 'The given data was invalid.',
            'errors': {
              'answers.first_name': ['First name is required.'],
            },
          },
        ),
      );

      await expectLater(
        repository.submitProposal('p1'),
        throwsA(
          isA<ApiException>()
              .having((e) => e.message, 'message', 'First name is required.')
              .having((e) => e.fieldErrors['answers.first_name'], 'field', 'First name is required.'),
        ),
      );
    });

    test('domain errors keep their code and message', () async {
      final (_, repository, _) = _repository(
        (_) => (409, {'message': 'This quote is no longer available.', 'code': 'quote_unavailable', 'errors': <String, Object>{}}),
      );

      await expectLater(
        repository.acceptQuote('q1', planKey: 'full'),
        throwsA(
          isA<ApiException>()
              .having((e) => e.code, 'code', 'quote_unavailable')
              .having((e) => e.message, 'message', 'This quote is no longer available.'),
        ),
      );
    });
  });

  group('dynamic form', () {
    test('shows a question only when its condition is met', () {
      final form = _form();

      expect(form.visibleQuestions({'has_dependants': false}).map((q) => q.key), ['has_dependants']);
      expect(form.visibleQuestions({'has_dependants': true}).map((q) => q.key), ['has_dependants', 'dependant_count']);
    });

    test('hides a question that depends on a hidden question', () {
      final keys = _form().visibleQuestions({'has_dependants': false, 'dependant_count': 2}).map((q) => q.key);

      expect(keys, ['has_dependants']);
    });

    test('conditional documents follow the same rule', () {
      final form = _form();

      expect(form.visibleDocuments({'has_dependants': false}), isEmpty);
      expect(form.visibleDocuments({'has_dependants': true}).single.key, 'birth_certificate');
    });
  });

  testWidgets('with no saved sign-in the app opens the sign-in screen', (tester) async {
    final (api, repository, _) = _repository((_) => (200, <String, Object>{}));
    await tester.pumpWidget(
      MizaniApp(session: SessionController(api: api, repository: repository, store: _MemoryStore())),
    );

    await tester.pumpAndSettle();

    expect(find.text('Send code'), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}

class _ThrowingAdapter implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async =>
      throw DioException.connectionError(requestOptions: options, reason: 'offline');

  @override
  void close({bool force = false}) {}
}
