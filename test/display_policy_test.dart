import 'package:flutter_test/flutter_test.dart';
import 'package:teumview/display_policy.dart';
void main(){test('overnight boundaries',(){expect(isNight(22,22,7),true);expect(isNight(0,22,7),true);expect(isNight(7,22,7),false);expect(isNight(12,22,7),false);});}
