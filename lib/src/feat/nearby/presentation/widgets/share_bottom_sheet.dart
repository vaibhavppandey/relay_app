import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:relay_app/pigeons/generated/media_saver.g.dart';
import 'package:relay_app/src/feat/nearby/data/repo/local_files_helper.dart';

class ShareBottomSheet extends StatelessWidget {
  const ShareBottomSheet({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.5,
      padding: EdgeInsets.all(16.w),
      child: FutureBuilder<List<File>>(
        future: LocalFilesHelper.getDownloadedFiles(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final lst = snap.data ?? [];
          if (lst.isEmpty) {
            return const Center(child: Text('No downloaded files'));
          }

          return ListView.builder(
            itemCount: lst.length,
            itemBuilder: (context, idx) {
              final file = lst[idx];
              return ListTile(
                title: Text(file.path.split('/').last),
                trailing: const Icon(Icons.share),
                onTap: () async {
                  final path = file.path;
                  final mime = 'application/octet-stream';
                  await MediaSaverApi().shareFile(path, mime);
                  if (!context.mounted) {
                    return;
                  }
                  Navigator.pop(context);
                },
              );
            },
          );
        },
      ),
    );
  }
}
