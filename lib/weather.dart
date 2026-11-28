import 'dart:convert';
import 'dart:io';

class WeatherReading {
  const WeatherReading(this.temperature, this.code, this.fetchedAt);
  final double temperature;
  final int code;
  final DateTime fetchedAt;
  String get description => switch(code) {0=>'맑음', 1||2=>'구름 조금', 3=>'흐림', 45||48=>'안개', >=51&&<=67=>'비', >=71&&<=77=>'눈', >=80&&<=82=>'소나기', >=95=>'뇌우', _=>'기타'};
}
Future<WeatherReading> fetchWeather(double lat,double lon) async {
  if(!lat.isFinite||!lon.isFinite||lat.abs()>90||lon.abs()>180) throw ArgumentError('Invalid coordinates');
  final client=HttpClient()..connectionTimeout=const Duration(seconds:10);
  try {
    final uri=Uri.https('api.open-meteo.com','/v1/forecast',{'latitude':'$lat','longitude':'$lon','current':'temperature_2m,weather_code'});
    final response=await (await client.getUrl(uri)).close().timeout(const Duration(seconds:15));
    if(response.statusCode!=200) throw HttpException('Weather unavailable');
    final data=jsonDecode(await response.transform(utf8.decoder).join().timeout(const Duration(seconds:15))) as Map;
    final current=data['current'] as Map;
    return WeatherReading((current['temperature_2m'] as num).toDouble(),(current['weather_code'] as num).toInt(),DateTime.now());
  } finally {client.close(force:true);}
}
