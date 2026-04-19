import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:relay_app/src/feat/transfer/bloc/transfer_bloc.dart';

class IncomingFilesWidget extends StatelessWidget {
  const IncomingFilesWidget({super.key});

  @override
  Widget build(BuildContext ctx) {
    return BlocBuilder<TransferBloc, TransferState>(
      builder: (ctx, state) {
        if (state is TransferIncoming) {
          if (state.list.isEmpty) {
            return const SizedBox.shrink();
          }

          return Expanded(
            child: ListView.builder(
              itemCount: state.list.length,
              itemBuilder: (ctx, i) {
                final item = state.list[i];
                return ListTile(
                  title: Text(item.fileName),
                  trailing: IconButton(
                    onPressed: () {
                      ctx.read<TransferBloc>().add(DownloadRequested(t: item));
                    },
                    icon: Icon(Icons.download, size: 20.r),
                  ),
                );
              },
            ),
          );
        }

        return const SizedBox.shrink();
      },
    );
  }
}
