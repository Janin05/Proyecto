import 'package:shared_preferences/shared_preferences.dart';

class LoginGuard {
  static const _kLockUntil = 'login_lock_until_ms';

  static Future<int> remainingLockMs() async {
    final sp = await SharedPreferences.getInstance();
    final until = sp.getInt(_kLockUntil) ?? 0;
    final now = DateTime.now().millisecondsSinceEpoch;
    return (until > now) ? (until - now) : 0;
  }

  static Future<void> lockForSeconds(int seconds) async {
    final sp = await SharedPreferences.getInstance();
    final until = DateTime.now()
        .add(Duration(seconds: seconds))
        .millisecondsSinceEpoch;
    await sp.setInt(_kLockUntil, until);
  }

  static Future<void> clear() async {
    final sp = await SharedPreferences.getInstance();
    await sp.remove(_kLockUntil);
  }
}
