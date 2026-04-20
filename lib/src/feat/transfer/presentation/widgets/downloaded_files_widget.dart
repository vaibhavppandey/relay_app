import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:path_provider/path_provider.dart';
import 'package:relay_app/pigeons/generated/media_saver.g.dart';
import 'package:relay_app/src/core/util/mime_type.dart';
import 'package:relay_app/src/feat/transfer/bloc/incoming/incoming_bloc.dart';

class DownloadedFilesWidget extends StatelessWidget {
  const DownloadedFilesWidget({super.key});

  Future<void> _share(BuildContext context, String fileName) async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final path = '${dir.path}/$fileName';
      final ok = await File(path).exists();
      if (!context.mounted) return;
      if (!ok) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Local file not found.')));
        return;
      }

      final mime = inferMimeType(fileName);
      await MediaSaverApi().shareFile(path, mime);
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to open share sheet.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<IncomingBloc, IncomingState>(
      builder: (context, state) {
        if (state is IncomingInitial || state is IncomingLoading) {
          return Padding(
            padding: EdgeInsets.symmetric(vertical: 12.h),
            child: Center(child: CircularProgressIndicator()),
          );
        }

        if (state is! IncomingLoaded && state is! IncomingFailure) {
          return const SizedBox.shrink();
        }

        final all = state is IncomingLoaded
            ? state.lst
            : (state as IncomingFailure).lst;
        final lst = all.where((t) => t.status == 'downloaded').toList();
        if (lst.isEmpty) {
          return _emptyState(context, 'No downloaded files available yet.');
        }

        return ListView.builder(
          itemCount: lst.length,
          itemBuilder: (context, i) {
            final t = lst[i];
            return ListTile(
              title: Text(t.fileName),
              trailing: IconButton(
                onPressed: () => _share(context, t.fileName),
                icon: Icon(Icons.share, size: 20.r),
              ),
            );
          },
        );
      },
    );
  }

  Widget _emptyState(BuildContext context, String message) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 12.h),
      child: Text(
        message,
        style: Theme.of(
          context,
        ).textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
      ),
    );
  }
}
