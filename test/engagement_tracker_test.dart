import 'package:flutter_test/flutter_test.dart';
import 'package:mappa_funghi_toscana/services/engagement_tracker.dart';

DateTime _d(int day) => DateTime(2026, 10, day);

/// Replays a run of sessions and returns the final state.
EngagementState _replay(List<DateTime> days) {
  var state = const EngagementState();
  DateTime? last;
  for (final day in days) {
    state = nextEngagement(current: state, lastOpenDay: last, today: day);
    last = day;
  }
  return state;
}

void main() {
  group('streak arithmetic', () {
    test('the very first session starts a streak of one', () {
      final s = _replay([_d(1)]);
      expect(s.streakDays, 1);
      expect(s.opensInStreak, 1);
      expect(s.totalOpens, 1);
    });

    test('a second session the same day raises intensity, not the streak', () {
      final s = _replay([_d(1), _d(1), _d(1)]);
      expect(s.streakDays, 1);
      expect(s.opensInStreak, 3);
    });

    test('consecutive days extend the streak', () {
      final s = _replay([_d(1), _d(2), _d(3)]);
      expect(s.streakDays, 3);
      expect(s.opensInStreak, 3);
    });

    test('a missed day resets the streak and the intensity', () {
      final s = _replay([_d(1), _d(2), _d(3), _d(5)]);
      expect(s.streakDays, 1);
      expect(s.opensInStreak, 1);
      expect(s.totalOpens, 4, reason: 'lifetime total must survive a reset');
    });

    test('a clock moved backwards resets rather than being trusted', () {
      final s = nextEngagement(
        current: const EngagementState(
            streakDays: 3, opensInStreak: 7, totalOpens: 7),
        lastOpenDay: _d(10),
        today: _d(8),
      );
      expect(s.streakDays, 1);
      expect(s.opensInStreak, 1);
    });
  });

  group('who gets asked', () {
    test('steady path: four consecutive days, one session each', () {
      expect(_replay([_d(1), _d(2), _d(3)]).qualifiesForInterview, isFalse);
      expect(_replay([_d(1), _d(2), _d(3), _d(4)]).qualifiesForInterview, isTrue);
    });

    test('intense path: three days fire a day earlier when opens exceed five', () {
      // 3 days, 6 sessions -> qualifies on day three
      final heavy = _replay([_d(1), _d(1), _d(2), _d(2), _d(3), _d(3)]);
      expect(heavy.streakDays, 3);
      expect(heavy.opensInStreak, 6);
      expect(heavy.qualifiesForInterview, isTrue);
    });

    test('exactly five opens over three days is NOT enough', () {
      // The threshold is strictly more than five.
      final s = _replay([_d(1), _d(1), _d(2), _d(2), _d(3)]);
      expect(s.streakDays, 3);
      expect(s.opensInStreak, 5);
      expect(s.qualifiesForInterview, isFalse);
    });

    test('heavy use crammed into two days does not qualify', () {
      final s = _replay([_d(1), _d(1), _d(1), _d(1), _d(2), _d(2), _d(2)]);
      expect(s.streakDays, 2);
      expect(s.opensInStreak, 7);
      expect(s.qualifiesForInterview, isFalse,
          reason: 'a burst is not the same as using it across days');
    });

    test('a broken streak stops qualifying again', () {
      // Four days, then a gap: back to square one.
      final s = _replay([_d(1), _d(2), _d(3), _d(4), _d(7)]);
      expect(s.qualifiesForInterview, isFalse);
    });

    test('bursty mushroom-season use misses the steady path', () {
      // Rain, two days out, nothing, rain again -- a realistic pattern that
      // deliberately does NOT trigger. Worth knowing if the prompt never
      // appears in the wild.
      final s = _replay([_d(1), _d(2), _d(5), _d(6)]);
      expect(s.streakDays, 2);
      expect(s.qualifiesForInterview, isFalse);
    });
  });
}
