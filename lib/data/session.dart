import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';

import '../models/models.dart';
import 'api_client.dart';
import 'client_repository.dart';
import 'session_store.dart';

/// Who is signed in. Screens read data through [repository] and call
/// [dataChanged] after a write so open tabs reload.
class SessionController extends ChangeNotifier {
  SessionController({
    required this.api,
    required this.repository,
    required this.store,
  }) {
    api.onUnauthorized = _expire;
  }

  final ApiClient api;
  final ClientRepository repository;
  final SessionStore store;

  /// Called when the session ends, by sign-out or an expired token.
  VoidCallback? onSignedOut;

  Client? _client;
  bool get isAuthenticated => _client != null;
  Client get client => _client!;

  int _dataVersion = 0;
  int get dataVersion => _dataVersion;

  void dataChanged() {
    _dataVersion++;
    notifyListeners();
  }

  void updateClient(Client client) {
    _client = client;
    notifyListeners();
  }

  /// Picks up a saved sign-in at launch. Returns false when there is none or
  /// it has expired. A network failure throws, so a client who is still
  /// signed in isn't sent back to the sign-in screen.
  Future<bool> restore() async {
    final token = await store.readToken();
    if (token == null) {
      return false;
    }

    api.token = token;
    try {
      _client = await repository.me();
      notifyListeners();
      return true;
    } on ApiException catch (e) {
      api.token = null;
      if (e.statusCode == 401) {
        await store.clearToken();
        return false;
      }
      rethrow;
    }
  }

  Future<OtpChallenge> requestCode(String identifier) =>
      repository.requestOtp(identifier);

  Future<void> verifyCode(String challengeId, String code) async {
    final result = await repository.verifyOtp(
      challengeId: challengeId,
      code: code,
      deviceId: await store.deviceId(),
    );
    await _begin(result);
  }

  Future<ProposalDetail> verifyInvitation(String token, String code) async {
    final session = await repository.verifyInvitation(
      token: token,
      code: code,
      deviceId: await store.deviceId(),
    );
    await _begin(session.auth);
    return session.proposal;
  }

  Future<void> signOut() async {
    final deviceId = await store.deviceId();
    await _quietly(() => repository.unregisterDevice(deviceId));
    await _quietly(repository.logout);
    await _clear();
  }

  Future<void> _begin(AuthResult result) async {
    api.token = result.token;
    await store.writeToken(result.token);
    _client = result.client;
    notifyListeners();

    final deviceId = await store.deviceId();
    await _quietly(
      () => repository.registerDevice(
        deviceId: deviceId,
        platform: Platform.isIOS ? 'ios' : 'android',
      ),
    );
  }

  Future<void> _quietly(Future<void> Function() action) async {
    try {
      await action();
    } on ApiException {
      // Housekeeping: it must never stop someone signing in or out.
    }
  }

  void _expire() {
    if (_client != null) {
      _clear();
    }
  }

  Future<void> _clear() async {
    api.token = null;
    _client = null;
    await store.clearToken();
    notifyListeners();
    onSignedOut?.call();
  }
}

final _money = NumberFormat('#,##0.##', 'en_US');
final _day = DateFormat('dd MMM yyyy', 'en_US');

/// Money as the server sent it. Only ever displayed, never calculated with.
String formatMoney(num amount, {String currency = 'KES'}) =>
    '$currency ${_money.format(amount)}';

String formatDate(DateTime date) => _day.format(date);
