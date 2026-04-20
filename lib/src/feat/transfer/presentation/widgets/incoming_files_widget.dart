import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:relay_app/src/feat/transfer/bloc/incoming/incoming_bloc.dart';
import 'package:relay_app/src/feat/transfer/bloc/transfer/transfer_bloc.dart';

class IncomingFilesWidget extends StatelessWidget {
  const IncomingFilesWidget({super.key});

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
        final lst = all
            .where((t) => t.status == 'transferring' || t.status == 'completed')
            .toList();
        if (lst.isEmpty) {
          return _emptyState(context, 'No incoming files available yet.');
        }

        return ListView.builder(
          itemCount: lst.length,
          itemBuilder: (context, i) {
            final item = lst[i];
            return BlocBuilder<TransferBloc, TransferState>(
              builder: (ctx, tState) {
                final isTransferring = item.status == 'transferring';
                final isActiveDl =
                    tState is TransferInProgress && tState.activeId == item.id;

                Widget subtitle;
                if (isTransferring) {
                  subtitle = const LinearProgressIndicator(value: null);
                } else if (isActiveDl) {
                  final pct = (tState.pct * 100).toInt();
                  subtitle = Row(
                    children: [
                      Expanded(
                        child: LinearProgressIndicator(value: tState.pct),
                      ),
                      SizedBox(width: 8.w),
                      Text('$pct%'),
                    ],
                  );
                } else {
                  subtitle = const Text('Ready to download');
                }

                return ListTile(
                  title: Text(item.fileName),
                  subtitle: subtitle,
                  trailing: isTransferring || isActiveDl
                      ? const SizedBox.shrink()
                      : IconButton(
                          onPressed: () {
                            ctx.read<TransferBloc>().add(
                              DownloadRequested(t: item),
                            );
                          },
                          icon: Icon(Icons.download, size: 20.r),
                        ),
                );
              },
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
