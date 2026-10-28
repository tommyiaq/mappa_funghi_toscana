import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../constants/app_constants.dart';
import '../services/engagement_tracker.dart';

/// Asks a frequent user, once and only once, to book a short call.
///
/// A booking page rather than a mail: picking a slot is one tap and ends in a
/// confirmed meeting, where a mail needs composing and then chasing.
Future<void> showInterviewPrompt(BuildContext context) async {
  // Spend the single ask the moment it is actually on screen, not when it
  // merely became due -- otherwise a prompt that failed to render is lost.
  await EngagementTracker.markAsked();
  if (!context.mounted) return;

  final accepted = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Mi daresti una mano?'),
      content: const Text(
        'Vedo che usi spesso l\'app. Sto cercando di capire come renderla '
        'più utile a chi va davvero a funghi.\n\n'
        'Ti va di farci una chiacchierata di dieci minuti? Scegli tu quando.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('No, grazie'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Prenota'),
        ),
      ],
    ),
  );

  if (accepted != true) return;

  final uri = Uri.parse(AppConstants.interviewBookingUrl);
  // The browser, not an in-app webview: booking may need a Google login, and
  // the confirmation belongs in their own browser session.
  final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
  if (opened) return;

  // No browser could be opened. Put the link on the clipboard so the one ask
  // we get is not wasted.
  await Clipboard.setData(
    const ClipboardData(text: AppConstants.interviewBookingUrl),
  );
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(
      content: Text('Link copiato: aprilo per scegliere un orario'),
      duration: Duration(seconds: 6),
    ),
  );
}
