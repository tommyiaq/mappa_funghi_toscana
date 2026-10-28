import 'package:shared_preferences/shared_preferences.dart';

import '../constants/app_constants.dart';

/// How engaged a user has been, in the only terms we can measure without
/// tracking anyone: consecutive days of use and sessions inside that run.
///
/// Everything here stays on the device. Nothing is transmitted, nothing
/// identifies a person, so the Play "Data safety" declaration stays at
/// "no data collected" -- which is also why this cannot tell us WHO opens the
/// app often, only let the app ask that person itself.
class EngagementState {
  final int streakDays;
  final int opensInStreak;
  final int totalOpens;

  const EngagementState({
    this.streakDays = 0,
    this.opensInStreak = 0,
    this.totalOpens = 0,
  });

  /// Two routes to the same profile: steady use over several days, or fewer
  /// days but heavy use inside them.
  bool get qualifiesForInterview =>
      streakDays >= AppConstants.interviewStreakDays ||
      (streakDays >= AppConstants.interviewIntenseStreakDays &&
          opensInStreak > AppConstants.interviewIntenseOpens);
}

/// Advances the counters for one new session. Pure, so the streak arithmetic
/// can be tested without touching storage or the clock.
///
/// [lastOpenDay] and [today] must both be date-only.
EngagementState nextEngagement({
  required EngagementState current,
  required DateTime? lastOpenDay,
  required DateTime today,
}) {
  if (lastOpenDay == null) {
    return EngagementState(
      streakDays: 1,
      opensInStreak: 1,
      totalOpens: current.totalOpens + 1,
    );
  }

  final gap = today.difference(lastOpenDay).inDays;
  final int streak;
  final int opens;
  if (gap == 0) {
    // Another session the same day: intensity grows, the streak does not.
    streak = current.streakDays == 0 ? 1 : current.streakDays;
    opens = current.opensInStreak + 1;
  } else if (gap == 1) {
    streak = current.streakDays + 1;
    opens = current.opensInStreak + 1;
  } else {
    // A missed day breaks it. A negative gap means the clock moved backwards,
    // which we treat the same way rather than trusting it.
    streak = 1;
    opens = 1;
  }

  return EngagementState(
    streakDays: streak,
    opensInStreak: opens,
    totalOpens: current.totalOpens + 1,
  );
}

class EngagementTracker {
  static const _kLastDay = 'engagement_last_day';
  static const _kStreak = 'engagement_streak_days';
  static const _kOpensInStreak = 'engagement_opens_in_streak';
  static const _kTotalOpens = 'engagement_total_opens';
  static const _kLastActivity = 'engagement_last_activity_ms';
  static const _kAsked = 'engagement_asked';

  /// Records a session and reports whether the interview prompt is due.
  ///
  /// Resuming from a short background spell is NOT a new session: without
  /// that guard, switching away and back a few times would reach the open
  /// count on its own. See AppConstants.sessionGap.
  ///
  /// Returns false forever once the prompt has been shown.
  static Future<bool> recordSessionAndCheck({DateTime? now}) async {
    final clock = now ?? DateTime.now();
    final prefs = await SharedPreferences.getInstance();

    if (prefs.getBool(_kAsked) ?? false) return false;

    final lastActivity = prefs.getInt(_kLastActivity);
    final nowMs = clock.millisecondsSinceEpoch;
    if (lastActivity != null &&
        nowMs - lastActivity < AppConstants.sessionGap.inMilliseconds &&
        nowMs >= lastActivity) {
      // Same session, just came back to the foreground.
      await prefs.setInt(_kLastActivity, nowMs);
      return false;
    }
    await prefs.setInt(_kLastActivity, nowMs);

    final today = DateTime(clock.year, clock.month, clock.day);
    final next = nextEngagement(
      current: EngagementState(
        streakDays: prefs.getInt(_kStreak) ?? 0,
        opensInStreak: prefs.getInt(_kOpensInStreak) ?? 0,
        totalOpens: prefs.getInt(_kTotalOpens) ?? 0,
      ),
      lastOpenDay: _parseDay(prefs.getString(_kLastDay)),
      today: today,
    );

    await prefs.setString(_kLastDay, _formatDay(today));
    await prefs.setInt(_kStreak, next.streakDays);
    await prefs.setInt(_kOpensInStreak, next.opensInStreak);
    await prefs.setInt(_kTotalOpens, next.totalOpens);

    return next.qualifiesForInterview;
  }

  /// Called once the prompt has actually been put in front of the user, so a
  /// prompt that never rendered is not counted as spent.
  static Future<void> markAsked() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kAsked, true);
  }

  static String _formatDay(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  static DateTime? _parseDay(String? raw) {
    if (raw == null) return null;
    final parts = raw.split('-');
    if (parts.length != 3) return null;
    final y = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    final d = int.tryParse(parts[2]);
    if (y == null || m == null || d == null) return null;
    return DateTime(y, m, d);
  }
}
