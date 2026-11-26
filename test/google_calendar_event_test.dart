import 'package:flutter_test/flutter_test.dart';
import 'package:teumview/google_calendar_service.dart';

void main(){
  test('all-day event preserves date and exclusive end date',(){
    final e=CalendarEvent.fromApi({'id':'one','summary':'휴가','start':{'date':'2026-11-26'},'end':{'date':'2026-11-27'}},'cal');
    expect(e,isNotNull);
    expect(e!.allDay,true);
    expect(e.start.day,26);
    expect(CalendarEvent.fromCache(e.toJson())!.title,'휴가');
  });
  test('cancelled events and invalid entries are skipped',(){
    expect(CalendarEvent.fromApi({'status':'cancelled'},'cal'),isNull);
    expect(CalendarEvent.fromApi({'start':{}},'cal'),isNull);
  });
}
