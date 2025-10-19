import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_flappy_bird/constants.dart';
import 'package:flutter_flappy_bird/multiplayer/op_codes.dart';
import 'package:nakama/nakama.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'multiplayer/player_state.dart';

class PipeSpawnEvent {
  final int id;
  final double x;
  final double xNormalized;
  final double gapYNormalized;
  final double? serverTime;

  PipeSpawnEvent({
    required this.id,
    required this.x,
    required this.xNormalized,
    required this.gapYNormalized,
    this.serverTime,
  });
}

class NakamaManager {
  NakamaBaseClient? _client;
  Session? _session;
  NakamaWebsocketClient? _socket;

  NakamaBaseClient? get client => _client;
  Session? get session => _session;
  NakamaWebsocketClient? get socket => _socket;

  final ValueNotifier<List<String>> playersNotifier =
      ValueNotifier<List<String>>([]);

  final ValueNotifier<bool> joinedNotifier = ValueNotifier<bool>(false);

  final ValueNotifier<Map<String, PlayerState>> playersStateNotifier =
      ValueNotifier<Map<String, PlayerState>>({});
  final ValueNotifier<int?> countdownNotifier = ValueNotifier<int?>(null);

  final ValueNotifier<String?> winnerNotifier = ValueNotifier<String?>(null);

  final ValueNotifier<PipeSpawnEvent?> pipeSpawnNotifier =
      ValueNotifier<PipeSpawnEvent?>(null);

  final ValueNotifier<Map<String, dynamic>?> physicsEventNotifier =
      ValueNotifier<Map<String, dynamic>?>(null);

  String? myUsername;
  String? currentMatchId;
  String? myUserId;
  String? lastWinnerId;

  double avgLatencyMs = 0;

  double get _screenHeight {
    final phSize =
        WidgetsBinding.instance.platformDispatcher.views.first.physicalSize;
    final dpr =
        WidgetsBinding.instance.platformDispatcher.views.first.devicePixelRatio;
    return phSize.height / dpr;
  }

  double get _screenWidth {
    final phSize =
        WidgetsBinding.instance.platformDispatcher.views.first.physicalSize;
    final dpr =
        WidgetsBinding.instance.platformDispatcher.views.first.devicePixelRatio;
    return phSize.width / dpr;
  }

  double _toPixelY(double yNormalized) =>
      denormalizeY(yNormalized, _screenHeight);

  double _toPixelX(double xNormalized) =>
      denormalizeX(xNormalized, _screenWidth);

  void initialize() {
    _client = getNakamaClient(
      host: '159.223.92.116',
      ssl: false,
      serverKey: 'defaultkey',
    );
  }

  Future<void> authenticate() async {
    final prefs = await SharedPreferences.getInstance();

    var deviceId = prefs.getString('nakama_device_id');
    if (deviceId == null || deviceId.isEmpty) {
      deviceId = const Uuid().v4();
      await prefs.setString('nakama_device_id', deviceId);
    }

    if (await _tryRestoreSession(prefs)) return;

    _session = await _client!.authenticateDevice(
      deviceId: deviceId,
      create: true,
      username: 'Player_${deviceId.substring(0, 5)}',
    );

    await _saveSession(prefs);
    await _updateUserInfo();
    debugPrint('[Auth] ✅ Authenticated: $myUsername (ID: $myUserId)');
  }

  // Thử restore session
  Future<bool> _tryRestoreSession(SharedPreferences prefs) async {
    final savedToken = prefs.getString('nakama_token');
    final savedRefresh = prefs.getString('nakama_refresh_token');
    if (savedToken == null || savedRefresh == null) return false;

    try {
      final oldSession = Session.restore(
        token: savedToken,
        refreshToken: savedRefresh,
      );

      if (oldSession == null || oldSession.isExpired) return false;

      _session = oldSession;
      await _updateUserInfo();
      debugPrint('[Auth] ✅ Restored session: $myUsername (ID: $myUserId)');
      return true;
    } catch (e) {
      debugPrint('[Auth] ⚠️ Failed to restore: $e');
      return false;
    }
  }

  // Lưu session
  Future<void> _saveSession(SharedPreferences prefs) async {
    await prefs.setString('nakama_token', _session!.token);
    if (_session!.refreshToken != null) {
      await prefs.setString('nakama_refresh_token', _session!.refreshToken!);
    }
  }

  // Cập nhật thông tin user
  Future<void> _updateUserInfo() async {
    final account = await _client!.getAccount(_session!);
    myUsername = account.user.displayName?.isNotEmpty == true
        ? account.user.displayName!
        : account.user.username;
    myUserId = account.user.id;
  }

  Future<void> updateUsername(String newDisplayName) async {
    if (_client == null || _session == null) return;
    final trimmed = newDisplayName.trim();
    if (trimmed.isEmpty) return;

    try {
      await _client!.updateAccount(session: _session!, displayName: trimmed);
      _session = await _client!.sessionRefresh(session: _session!);
      myUsername = trimmed;
      debugPrint('[Account] ✅ Updated: $trimmed');
    } catch (e) {
      debugPrint('[Account] ❌ Error: $e');
    }
  }

  Future<void> connectSocket() async {
    if (_session == null) {
      throw Exception('[Socket] Không thể kết nối vì chưa authenticate.');
    }
    if (_socket != null) return;

    try {
      _socket = NakamaWebsocketClient.init(
        host: '159.223.92.116',
        port: 7350,
        ssl: false,
        token: _session!.token,
      );

      myUserId = _session!.userId;

      _socket!.onMatchData.listen(_handleMatchData);
      _socket!.onMatchPresence.listen(_handlePresenceUpdate);

      debugPrint('[Socket] Kết nối websocket thành công');
    } catch (e) {
      debugPrint('[Socket] Lỗi khi kết nối websocket: $e');
    }
  }

  void _handlePresenceUpdate(MatchPresenceEvent e) {
    if (e.joins.isNotEmpty) {
      debugPrint('[Presence] ${e.joins.length} player(s) joined');
    }

    if (e.leaves.isNotEmpty) {
      debugPrint('[Presence] ${e.leaves.length} player(s) left');

      final current = List<String>.from(playersNotifier.value);
      current.removeWhere(
        (name) => e.leaves.any(
          (leave) => name == leave.username || name == leave.userId,
        ),
      );

      if (!listEquals(playersNotifier.value, current)) {
        playersNotifier.value = current;
      }
    }
  }

  void _handleMatchData(MatchData event) {
    if (event.data == null) return;

    final json = utf8.decode(event.data!);
    final data = jsonDecode(json);

    switch (event.opCode) {
      case OpCode.lobbyUpdate:
        final playersData = data['players'];
        if (playersData is List) {
          // Lấy danh sách tên players
          final names = playersData.map((p) {
            final displayName = p['displayName']?.toString();
            final username = p['username']?.toString();
            return (displayName?.isNotEmpty == true)
                ? displayName!
                : (username ?? 'Unknown');
          }).toList();

          if (!listEquals(playersNotifier.value, names)) {
            playersNotifier.value = List<String>.from(names);
          }

          // Cập nhật player states
          final newStates = <String, PlayerState>{};
          for (final p in playersData) {
            final userId = p['userId']?.toString();
            if (userId == null) continue;

            final displayName = p['displayName']?.toString();
            final username = p['username']?.toString() ?? 'Unknown';
            final finalName = (displayName?.isNotEmpty == true)
                ? displayName!
                : username;

            final yNormalized = (p['birdY'] ?? 0.5).toDouble();
            final birdY = _toPixelY(yNormalized);

            newStates[userId] = PlayerState(
              userId: userId,
              username: finalName,
              birdY: birdY,
              velocity: (p['velocity'] ?? 0).toDouble(),
              isAlive: p['isAlive'] ?? true,
              score: p['score'] ?? 0,
            );
          }

          if (!mapEquals(playersStateNotifier.value, newStates)) {
            playersStateNotifier.value = newStates;
          }
        }
        break;

      case OpCode.countdown:
        final value = data['value'];
        if (value is int && countdownNotifier.value != value) {
          countdownNotifier.value = value;
        }
        break;

      case OpCode.startGame:
        if (!joinedNotifier.value) joinedNotifier.value = true;
        break;

      case OpCode.gameFinished:
        lastWinnerId = (data['winnerId'] ?? '').toString();
        final winnerName = (data['winner'] ?? '').toString();
        debugPrint('[GameFinished] 🏆 Winner: $winnerName (ID: $lastWinnerId)');
        if (winnerNotifier.value != winnerName) {
          winnerNotifier.value = winnerName;
          debugPrint('[GameFinished] ✅ Winner notifier updated');
        } else {
          debugPrint('[GameFinished] ⚠️ Winner notifier already set');
        }
        break;

      case OpCode.pipeSpawn:
        final id = (data['id'] ?? 0) as int;
        final xNormalized = (data['xNormalized'] ?? 1.0).toDouble();
        final gapYNormalized = (data['gapYNormalized'] ?? 0.5).toDouble();

        pipeSpawnNotifier.value = PipeSpawnEvent(
          id: id,
          x: _toPixelX(xNormalized),
          xNormalized: xNormalized,
          gapYNormalized: gapYNormalized,
        );
        break;

      case OpCode.playerFlap:
        final userId = data['userId'];
        final yNormalized = (data['yNormalized'] ?? 0.5).toDouble();
        final velocity = (data['velocity'] ?? 0).toDouble();
        final timestamp = data['timestamp'] as int?;
        final y = _toPixelY(yNormalized);

        // Cập nhật player state
        final current = Map<String, PlayerState>.from(
          playersStateNotifier.value,
        );
        final old = current[userId];
        if (old != null) {
          current[userId] = old.copyWith(birdY: y, velocity: velocity);
          playersStateNotifier.value = current;
        }

        // Notify event
        if (NetworkConfig.useClientAuthoritative && userId != myUserId) {
          physicsEventNotifier.value = {
            'eventType': 'PLAYER_FLAP',
            'userId': userId,
            'yNormalized': yNormalized,
            'velocity': velocity,
            'timestamp': timestamp ?? DateTime.now().millisecondsSinceEpoch,
          };
        }
        break;

      case OpCode.positionCorrection:
        final corrections = data['corrections'] as List?;
        if (corrections == null) break;

        final current = Map<String, PlayerState>.from(
          playersStateNotifier.value,
        );

        for (final correction in corrections) {
          final userId = correction['userId'];
          if (userId == null || userId == myUserId) continue;

          final yNormalized = (correction['yNormalized'] ?? 0.5).toDouble();
          final y = _toPixelY(yNormalized);
          final velocity = (correction['velocity'] ?? 0.0).toDouble();

          final old = current[userId];
          if (old != null) {
            current[userId] = old.copyWith(birdY: y, velocity: velocity);
          }

          if (NetworkConfig.useClientAuthoritative) {
            physicsEventNotifier.value = {
              'eventType': 'POSITION_CORRECTION',
              'userId': userId,
              'yNormalized': yNormalized,
              'velocity': velocity,
            };
          }
        }

        playersStateNotifier.value = current;
        break;

      case OpCode.validationError:
        final reason = data['reason'] ?? 'Unknown error';
        debugPrint('[Validation] Rejected: $reason');

        final correctedY = data['correctedY'];
        final correctedVelocity = data['correctedVelocity'];
        if (correctedY != null && correctedVelocity != null) {
          debugPrint(
            '[Validation] Correction: y=$correctedY, v=$correctedVelocity',
          );
        }
        break;

      case OpCode.playerDied:
        final userId = data['userId'];
        final yNormalized = (data['yNormalized'] as num?)?.toDouble();
        final finalScore = data['finalScore'] as int?;
        final timestamp = data['timestamp'] as int?;
        final y = yNormalized != null ? _toPixelY(yNormalized) : null;

        final current = Map<String, PlayerState>.from(
          playersStateNotifier.value,
        );
        final old = current[userId];
        if (old != null && old.isAlive) {
          current[userId] = old.copyWith(
            isAlive: false,
            birdY: y ?? old.birdY,
            score: finalScore ?? old.score,
          );
          playersStateNotifier.value = current;
        }

        if (NetworkConfig.useClientAuthoritative && userId != myUserId) {
          physicsEventNotifier.value = {
            'eventType': 'PLAYER_DIED',
            'userId': userId,
            'yNormalized': yNormalized,
            'finalScore': finalScore,
            'timestamp': timestamp ?? DateTime.now().millisecondsSinceEpoch,
          };
        }
        break;

      case OpCode.playerScored:
        final userId = data['userId'];
        final score = data['score'] ?? 0;
        final yNormalized = (data['yNormalized'] as num?)?.toDouble();
        final velocity = (data['velocity'] as num?)?.toDouble();
        final timestamp = data['timestamp'] as int?;
        final y = yNormalized != null ? _toPixelY(yNormalized) : null;

        final current = Map<String, PlayerState>.from(
          playersStateNotifier.value,
        );
        final old = current[userId];
        if (old != null) {
          current[userId] = old.copyWith(
            score: score,
            birdY: y ?? old.birdY,
            velocity: velocity ?? old.velocity,
          );
          playersStateNotifier.value = current;
        }

        if (NetworkConfig.useClientAuthoritative && userId != myUserId) {
          physicsEventNotifier.value = {
            'eventType': 'PLAYER_SCORED',
            'userId': userId,
            'yNormalized': yNormalized,
            'velocity': velocity,
            'score': score,
            'timestamp': timestamp ?? DateTime.now().millisecondsSinceEpoch,
          };
        }
        break;

      default:
        debugPrint('[Socket] Bỏ qua OpCode không xác định: ${event.opCode}');
        break;
    }
  }

  // Gửi match data
  void _sendMatchData(
    int opCode,
    Map<String, dynamic> payload, [
    String? debugTag,
  ]) {
    if (_socket == null || currentMatchId == null) return;

    try {
      _socket!.sendMatchData(
        matchId: currentMatchId!,
        opCode: opCode,
        data: utf8.encode(jsonEncode(payload)),
      );
      if (debugTag != null) debugPrint('[$debugTag] Sent');
    } catch (e) {
      if (debugTag != null) debugPrint('[$debugTag] Error: $e');
    }
  }

  void sendReady() {
    _sendMatchData(OpCode.lobbyUpdate, {
      'event': 'ready',
      'userId': myUserId,
      'username': myUsername,
    }, 'Ready');
  }

  void sendCancelReady() {
    _sendMatchData(OpCode.lobbyUpdate, {
      'event': 'cancel_ready',
      'userId': myUserId,
      'username': myUsername,
    }, 'CancelReady');
  }

  void resetLobbyState() {
    joinedNotifier.value = false;
    countdownNotifier.value = null;
    playersNotifier.value = [];
    playersStateNotifier.value = {};
    winnerNotifier.value = null;
  }

  void sendFlap(double birdY, double velocity) {
    _sendMatchData(OpCode.playerFlap, {'y': birdY, 'velocity': velocity});
  }

  void sendPhysicsEvent(String eventType, Map<String, dynamic> eventData) {
    final opCodeMap = {
      'PLAYER_FLAP': OpCode.playerFlap,
      'PLAYER_SCORED': OpCode.playerScored,
      'PLAYER_DIED': OpCode.playerDied,
    };

    final opCode = opCodeMap[eventType];
    if (opCode == null) {
      debugPrint('[Physics] Unknown event: $eventType');
      return;
    }

    _sendMatchData(opCode, eventData);
  }

  void sendDied() {
    _sendMatchData(OpCode.playerDied, {});
  }

  void sendScore(int score) {
    _sendMatchData(OpCode.playerScored, {'score': score});
  }

  Future<void> findOrCreateMatch(String username) async {
    if (_client == null) throw Exception('[Match] Client chưa sẵn sàng');
    if (_session == null) throw Exception('[Match] Session chưa có');
    if (_socket == null) throw Exception('[Match] Socket chưa kết nối');

    if (_session!.isExpired) {
      _session = await _client!.sessionRefresh(session: _session!);
    }

    final rpcResult = await _client!.rpc(
      id: 'get_waiting_match',
      payload: '{}',
      session: _session!,
    );

    final matchId = rpcResult?.toString();
    if (matchId == null || matchId.isEmpty) {
      throw Exception(
        '[Match] RPC get_waiting_match không trả về matchId hợp lệ',
      );
    }

    currentMatchId = matchId;
    debugPrint('[Match] Đã nhận matchId: $matchId');

    final match = await _socket!.joinMatch(matchId);

    final me = (myUsername?.isNotEmpty == true) ? myUsername! : username;
    final names = <String>{
      me,
      ...match.presences.map(
        (p) => p.username.isNotEmpty ? p.username : p.userId,
      ),
    }.toList();

    playersNotifier.value = names;
    debugPrint(
      '[Match] Đã tham gia phòng: ${match.matchId} (${names.length} người chơi)',
    );
  }

  Future<void> cancelMatchmaking() async {
    if (_socket == null || currentMatchId == null) return;

    try {
      await _socket!.leaveMatch(currentMatchId!);
      debugPrint('[Match] Đã rời khỏi trận $currentMatchId');
    } catch (e) {
      debugPrint('[Match] Lỗi khi rời match: $e');
    } finally {
      currentMatchId = null;
      resetLobbyState();
      debugPrint('[Match] Đã reset trạng thái matchmaking');
    }
  }

  void requestInitialState() {
    _sendMatchData(OpCode.lobbyUpdate, {'event': 'sync_request'});
  }
}
