import 'package:flutter/material.dart';
import '../models/presence_model.dart';
import '../services/presence_service.dart';

class PresenceProvider with ChangeNotifier {
  List<PresenceModel> _presences = [];

  List<PresenceModel> get presences => _presences;

  PresenceModel? _todayPresence;

  PresenceModel? get todayPresence => _todayPresence;

  void setTodayPresence(PresenceModel? presence) {
    _todayPresence = presence;
    notifyListeners();
  }

  Future<void> fetchPresences() async {
    try {
      print('Starting fetchPresences...');
      final response = await PresenceService().getPresences();
      print('Got response from service: ${response.length} items');
      _presences = response;
      notifyListeners();
      print('Presences updated in provider');
    } catch (e) {
      print('Error in fetchPresences: $e');
      rethrow;
    }
  }
}
