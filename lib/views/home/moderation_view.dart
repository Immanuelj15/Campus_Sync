import 'package:flutter/material.dart';
import 'package:campus_sync/models/moderation_report_model.dart';
import 'package:campus_sync/services/db_service.dart';

class ModerationView extends StatelessWidget {
  const ModerationView({super.key});

  @override
  Widget build(BuildContext context) {
    final dbService = DbService();

    return Scaffold(
      appBar: AppBar(title: const Text('Moderation Desk')),
      body: StreamBuilder<List<ModerationReportModel>>(
        stream: dbService.reports(),
        builder: (context, snapshot) {
          final reports = snapshot.data ?? const <ModerationReportModel>[];
          if (reports.isEmpty) {
            return const Center(
              child: Text('No reports yet. The moderation queue is clear.'),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: reports.length,
            separatorBuilder: (context, index) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final report = reports[index];
              return Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(22),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      report.postTitle,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text('Reason: ${report.reason}'),
                    const SizedBox(height: 8),
                    Text('Reported by: ${report.reportedByEmail}'),
                    const SizedBox(height: 8),
                    Text('Post ID: ${report.postId}'),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
