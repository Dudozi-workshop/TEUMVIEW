import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// The Calendar API and OAuth consent screen must be enabled in Google Cloud.
/// User-interactive authorization is only initiated by [connect].
class CalendarEvent {
  const CalendarEvent({required this.id, required this.calendarId, required this.title,
    required this.start, required this.end, required this.allDay});
  final String id, calendarId, title;
  final DateTime start, end;
  final bool allDay;

  static CalendarEvent? fromApi(Map<String, dynamic> json, String calendarId) {
    if (json['status'] == 'cancelled') return null;
    final startData = json['start'];
    final endData = json['end'];
    if (startData is! Map || endData is! Map) return null;
    final allDay = startData['date'] != null;
    final start = DateTime.tryParse('${startData['dateTime'] ?? startData['date'] ?? ''}');
    final end = DateTime.tryParse('${endData['dateTime'] ?? endData['date'] ?? ''}');
    if (start == null || end == null) return null;
    return CalendarEvent(id: '${json['id'] ?? ''}', calendarId: calendarId,
      title: '${json['summary'] ?? '제목 없음'}', start: start, end: end, allDay: allDay);
  }
  Map<String, dynamic> toJson() => {'id':id,'calendarId':calendarId,'title':title,
    'start':start.toIso8601String(),'end':end.toIso8601String(),'allDay':allDay};
  static CalendarEvent? fromCache(dynamic item) {
    if (item is! Map) return null;
    final value = Map<String,dynamic>.from(item);
    final start = DateTime.tryParse('${value['start'] ?? ''}');
    final end = DateTime.tryParse('${value['end'] ?? ''}');
    if (start==null || end==null) return null;
    return CalendarEvent(id:'${value['id'] ?? ''}',calendarId:'${value['calendarId'] ?? ''}',
      title:'${value['title'] ?? ''}',start:start,end:end,allDay:value['allDay']==true);
  }
}

class CalendarChoice {
  const CalendarChoice(this.id,this.label,this.primary);
  final String id, label;
  final bool primary;
}

class CalendarService {
  CalendarService._();
  static final instance = CalendarService._();
  static const scopes = ['https://www.googleapis.com/auth/calendar.readonly'];
  static const selectedKey = 'google_calendar_selected';
  static const cacheKey = 'google_calendar_cache';
  static const cacheTimeKey = 'google_calendar_fetched_at';
  static const _base = 'https://www.googleapis.com/calendar/v3';
  final changes = ValueNotifier<int>(0);
  final signIn = GoogleSignIn.instance;
  GoogleSignInAccount? account;
  Future<void>? _initialization;

  Future<void> initialize() => _initialization ??= _initialize();
  Future<void> _initialize() async {
    await signIn.initialize();
    account = await signIn.attemptLightweightAuthentication();
    changes.value++;
  }
  Future<void> connect() async {
    await initialize();
    if (!signIn.supportsAuthenticate()) throw StateError('Interactive Google sign-in unavailable');
    final user = account ?? await signIn.authenticate();
    // A consent screen can only be opened following explicit user action.
    await user.authorizationClient.authorizeScopes(scopes);
    account = user;
    changes.value++;
  }
  Future<void> disconnect(SharedPreferences prefs) async {
    await initialize();
    await signIn.signOut();
    account = null;
    await prefs.remove(selectedKey);
    await prefs.remove(cacheKey);
    await prefs.remove(cacheTimeKey);
    changes.value++;
  }
  List<String> selected(SharedPreferences prefs) => prefs.getStringList(selectedKey) ?? [];
  List<CalendarEvent> cached(SharedPreferences prefs) {
    try {
      final raw = jsonDecode(prefs.getString(cacheKey) ?? '[]') as List;
      return raw.map(CalendarEvent.fromCache).whereType<CalendarEvent>().toList()
        ..sort((a,b)=>a.start.compareTo(b.start));
    } catch (_) {return [];}
  }
  DateTime? lastUpdated(SharedPreferences prefs) =>
      DateTime.tryParse(prefs.getString(cacheTimeKey) ?? '');
  Future<Map<String,dynamic>> _request(Uri uri, String token) async {
    final result = await http.get(uri, headers: {'Authorization':'Bearer $token'}).timeout(const Duration(seconds:15));
    if (result.statusCode != 200) throw StateError('Google Calendar HTTP ${result.statusCode}');
    final decoded = jsonDecode(result.body);
    if (decoded is! Map<String,dynamic>) throw const FormatException('Invalid calendar response');
    return decoded;
  }
  Future<String> _token() async {
    await initialize();
    final user = account;
    if (user == null) throw StateError('Google account not connected');
    final auth = await user.authorizationClient.authorizationForScopes(scopes);
    if (auth == null) throw StateError('Calendar permission required; reconnect');
    return auth.accessToken;
  }
  Future<List<CalendarChoice>> listCalendars() async {
    final token = await _token();
    final output = <CalendarChoice>[];
    String? page;
    do {
      final query = {'maxResults':'100',if(page!=null)'pageToken':page};
      final data = await _request(Uri.parse('$_base/users/me/calendarList').replace(queryParameters:query),token);
      for (final item in data['items'] is List ? data['items'] as List : <dynamic>[]) {
        if (item is Map && item['id'] is String && item['deleted'] != true) {
          output.add(CalendarChoice(item['id'] as String,'${item['summaryOverride'] ?? item['summary'] ?? item['id']}',item['primary']==true));
        }
      }
      page = data['nextPageToken'] as String?;
    } while(page!=null && output.length<500);
    return output;
  }
  Future<void> saveSelected(SharedPreferences prefs,List<String> ids) async {
    await prefs.setStringList(selectedKey,ids.toSet().toList());
    await prefs.remove(cacheKey);
    await prefs.remove(cacheTimeKey);
    changes.value++;
  }
  Future<List<CalendarEvent>> refresh(SharedPreferences prefs) async {
    final token=await _token();
    final ids=selected(prefs);
    if(ids.isEmpty) return [];
    final today=DateTime.now();
    final from=DateTime(today.year,today.month,today.day);
    final to=from.add(const Duration(days:30));
    final output=<CalendarEvent>[];
    for(final id in ids) {
      String? page;
      do {
        final uri=Uri.parse('$_base/calendars/${Uri.encodeComponent(id)}/events').replace(queryParameters:{
          'singleEvents':'true','orderBy':'startTime','maxResults':'200',
          'timeMin':from.toUtc().toIso8601String(), 'timeMax':to.toUtc().toIso8601String(),
          if(page!=null)'pageToken':page,
        });
        final data=await _request(uri,token);
        for(final item in data['items'] is List ? data['items'] as List : <dynamic>[]) {
          if(item is Map) {
            final event=CalendarEvent.fromApi(Map<String,dynamic>.from(item),id);
            if(event!=null) output.add(event);
          }
        }
        page=data['nextPageToken'] as String?;
      } while(page!=null && output.length<1000);
    }
    output.sort((a,b)=>a.start.compareTo(b.start));
    // Event summaries remain on this device only; excluded from export/backup.
    if(account==null || selected(prefs).join('\n')!=ids.join('\n')) return [];
    await prefs.setString(cacheKey,jsonEncode(output.map((e)=>e.toJson()).toList()));
    await prefs.setString(cacheTimeKey,DateTime.now().toIso8601String());
    changes.value++;
    return output;
  }
}
