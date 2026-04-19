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

  Future<void> _share(BuildContext ctx, String fileName) async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final path = '${dir.path}/$fileName';
      final ok = await File(path).exists();
      if (!ctx.mounted) return;
      if (!ok) {
        ScaffoldMessenger.of(
          ctx,
        ).showSnackBar(const SnackBar(content: Text('Local file not found.')));
        return;
      }

      final mime = inferMimeType(fileName);
      await MediaSaverApi().shareFile(path, mime);
    } catch (_) {
      if (!ctx.mounted) return;
      ScaffoldMessenger.of(ctx).showSnackBar(
        const SnackBar(content: Text('Unable to open share sheet.')),
      );
    }
  }

  @override
  Widget build(BuildContext ctx) {
    return BlocBuilder<IncomingBloc, IncomingState>(
      builder: (ctx, state) {
        if (state is! IncomingLoaded && state is! IncomingFailure) {
          return const SizedBox.shrink();
        }

        final all = state is IncomingLoaded
            ? state.lst
            : (state as IncomingFailure).lst;
        final lst = all.where((t) => t.status == 'downloaded').toList();
        if (lst.isEmpty) {
          return const SizedBox.shrink();
        }

        return Expanded(
          child: ListView.builder(
            itemCount: lst.length,
            itemBuilder: (ctx, i) {
              final t = lst[i];
              return ListTile(
                title: Text(t.fileName),
                trailing: IconButton(
                  onPressed: () => _share(ctx, t.fileName),
                  icon: Icon(Icons.share, size: 20.r),
                ),
              );
            },
          ),
        );
      },
    );
  }
}
