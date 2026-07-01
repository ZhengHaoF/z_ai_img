import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/network_log.dart';

class NetworkLogNotifier extends StateNotifier<List<NetworkLog>> {
  NetworkLogNotifier() : super([]);

  void addLog(NetworkLog log) {
    state = [log, ...state].take(100).toList();
  }

  void clearLogs() {
    state = [];
  }
}

final networkLogProvider =
    StateNotifierProvider<NetworkLogNotifier, List<NetworkLog>>((ref) {
  return NetworkLogNotifier();
});
