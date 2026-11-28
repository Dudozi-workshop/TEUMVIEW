import 'package:flutter_test/flutter_test.dart';
import 'package:teumview/google_calendar_service.dart';

void main(){
  test('all-day event preserves date and exclusive end date',(){
    final e=CalendarEvent.fromApi({'id':'one','summary':'휴가','start':{'date':'2026-11-26'},'end':{'date':'2026-11-27'}},'cal');
    expect(e,isNotNull);
    expect(e!.allDay,true);
    expect(e.displayStart, DateTime(2026, 11, 26));
    expect(CalendarEvent.fromCache(e.toJson())!.title,'휴가');
  });
  test('timed events display local time after loading from API or cache', () {
    final event = CalendarEvent.fromApi({
      'start': {'dateTime': '2026-11-27T00:30:00+09:00'},
      'end': {'dateTime': '2026-11-27T01:30:00+09:00'},
    }, 'cal')!;
    final expected = DateTime.utc(2026, 11, 26, 15, 30).toLocal();
    for (final item in [event, CalendarEvent.fromCache(event.toJson())!]) {
      expect(item.displayStart, expected);
      expect(item.displayStart.isUtc, isFalse);
    }
  });
  test('cancelled events and invalid entries are skipped',(){
    expect(CalendarEvent.fromApi({'status':'cancelled'},'cal'),isNull);
    expect(CalendarEvent.fromApi({'start':{}},'cal'),isNull);
  });
}
