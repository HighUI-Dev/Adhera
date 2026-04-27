import 'package:flutter/material.dart';
import 'package:adhera/services/localization_service.dart';
import 'package:adhera/services/notification_service.dart';

class DemoNotificationsPage extends StatelessWidget {
  const DemoNotificationsPage({super.key});

  Future<void> _sendDemoNotification(
    BuildContext context,
    Future<void> Function() sender,
  ) async {
    await sender();
    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(context.t('demo_notification_sent'))),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(context.t('demo_notifications')),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  gradient: LinearGradient(
                    colors: [
                      colorScheme.primaryContainer,
                      colorScheme.secondaryContainer,
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.t('demo_notifications'),
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: colorScheme.onPrimaryContainer,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      context.t('demo_notifications_subtitle'),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onPrimaryContainer.withOpacity(
                          0.82,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              _NotificationDemoCard(
                icon: Icons.medication_outlined,
                color: Colors.teal,
                title: context.t('daily_notification_reminder_title'),
                body: context.t('daily_notification_reminder_body'),
                buttonLabel: context.t('send_notification'),
                onPressed: () => _sendDemoNotification(
                  context,
                  NotificationService.instance.showDailyReminderDemo,
                ),
              ),
              const SizedBox(height: 12),
              _NotificationDemoCard(
                icon: Icons.notifications_active_outlined,
                color: Colors.orange,
                title: context.t('missed_dose_alert_title'),
                body: context.t('missed_dose_alert_body'),
                buttonLabel: context.t('send_notification'),
                onPressed: () => _sendDemoNotification(
                  context,
                  NotificationService.instance.showMissedDoseAlertDemo,
                ),
              ),
              const SizedBox(height: 12),
              _NotificationDemoCard(
                icon: Icons.campaign_outlined,
                color: Colors.indigo,
                title: context.t('missed_dose_followup_title'),
                body: context.t('missed_dose_followup_body'),
                buttonLabel: context.t('send_notification'),
                onPressed: () => _sendDemoNotification(
                  context,
                  NotificationService.instance.showMissedDoseFollowupDemo,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NotificationDemoCard extends StatelessWidget {
  const _NotificationDemoCard({
    required this.icon,
    required this.color,
    required this.title,
    required this.body,
    required this.buttonLabel,
    required this.onPressed,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String body;
  final String buttonLabel;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(icon, color: color),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(body, style: theme.textTheme.bodyMedium),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: onPressed,
                icon: const Icon(Icons.send_outlined),
                label: Text(buttonLabel),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
