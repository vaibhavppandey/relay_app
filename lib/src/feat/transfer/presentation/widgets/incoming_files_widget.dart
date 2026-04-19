import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:relay_app/src/feat/transfer/bloc/incoming/incoming_bloc.dart';
import 'package:relay_app/src/feat/transfer/bloc/transfer/transfer_bloc.dart';

class IncomingFilesWidget extends StatelessWidget {
  const IncomingFilesWidget({super.key});

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
        final lst = all.where((t) => t.status == 'completed').toList();
        if (lst.isEmpty) {
          return const SizedBox.shrink();
        }

        return Expanded(
          child: ListView.builder(
            itemCount: lst.length,
            itemBuilder: (ctx, i) {
              final item = lst[i];
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
      },
    );
  }
}
