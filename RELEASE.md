# Release process

## Steps

1. **Do not bump the version by hand.** `pubspec.yaml` should hold the build
   number that is currently live on Play. The source of truth is Play Console
   → Bundle explorer, *not* this file.
2. `flutter build appbundle --release`
3. Upload `build/app/outputs/bundle/release/app-release.aab` to the
   **internal testing** track and test it on a real device.
4. When it looks right, **push this repo**. Codemagic picks up the push, runs
   `scripts/bump_version.py`, builds, and releases to **production**.

**Do not promote the internal-testing release to production by hand.** Pushing
is what ships it. Promoting manually *and* pushing would put the same code
through review twice.

## Version numbers

`scripts/bump_version.py` increments only the `+build` part. Change the
`major.minor.patch` name by hand when a release deserves it.

Play enforces uniqueness on the build number and never looks at the contents,
so the same code re-uploaded under a new build number is accepted without
complaint. That is why the number here must track Play: if it drifts ahead
(e.g. from running the bump script locally), the next automated build skips
numbers for no reason.

## Never push while a release is under review

A push produces a new production release. If one is already in review, the new
one supersedes it and **the review starts over** — for byte-identical code that
can cost days. Wait for the pending release to publish first.

## Unverified: does the push actually publish?

Codemagic's workflow is configured in its web UI. There is no `codemagic.yaml`
in this repo, so neither the trigger nor the publishing target can be confirmed
from the code.

Observed 2026-09-07: `main` was pushed and **no new bundle appeared on Play**
(highest uploaded build stayed at 20). The trigger *does* fire — Codemagic
build **#28** ran on `main` / "Default Workflow" and failed with
`Failed to build for Android`. So the push-to-production path is wired up but
currently broken at the build step.

Note this is a *build* failure, not a publish rejection: a release already in
review cannot make Gradle fail, it would fail later at the upload step with a
Play API error.

First thing to check: `android/key.properties` is gitignored
(`android/.gitignore`), so a clean CI checkout does not contain it, and
`android/app/build.gradle.kts` does `keystoreProperties["keyAlias"] as String`
— which throws if the file is missing. Codemagic normally writes that file from
its own Android signing settings, so confirm those are configured for this app.

Until build #28 (or later) goes green, treat step 4 as broken: upload and
promote by hand, and always verify in Play Console that a bundle actually
appeared.

## History

- **20 (1.4.0)** — temperature-aware markers, dynamic rain window, per-mushroom
  temperature ranges, interpolated temperatures for sensorless stations,
  Archivio threshold lowered to 20 mm. Uploaded by hand and promoted by hand
  (before the push-to-production workflow above was adopted).
