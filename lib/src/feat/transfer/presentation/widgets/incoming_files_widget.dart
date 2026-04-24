import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:relay_app/src/feat/transfer/bloc/incoming/incoming_bloc.dart';
import 'package:relay_app/src/feat/transfer/bloc/transfer/transfer_bloc.dart';
import 'package:relay_app/src/feat/transfer/presentation/widgets/incoming_state_view.dart';

class IncomingFilesWidget extends StatelessWidget {
  const IncomingFilesWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<IncomingBloc, IncomingState>(
      builder: (context, state) {
        if (state.isLoading) {
          return Padding(
            padding: EdgeInsets.symmetric(vertical: 12.h),
            child: Center(child: CircularProgressIndicator()),
          );
        }

        final all = state.transfersOrNull;
        if (all == null) {
          return const SizedBox.shrink();
        }

        final lst = all
            .where((t) => t.status == 'transferring' || t.status == 'completed')
            .toList();
        if (lst.isEmpty) {
          return _emptyState(context, 'No incoming files available yet.');
        }

        return BlocBuilder<TransferBloc, TransferState>(
          builder: (context, tState) {
            final activeDownloadId = _activeDownloadId(tState);
            final activeDownloadPct = _activeDownloadPct(tState);
            final isAnyDownloadBusy = activeDownloadId != null;

            return ListView.builder(
              itemCount: lst.length,
              itemBuilder: (context, i) {
                final item = lst[i];
                final isTransferring = item.status == 'transferring';
                final isActiveDownload = activeDownloadId == item.id;

                Widget subtitle;
                if (isTransferring) {
                  subtitle = const LinearProgressIndicator(value: null);
                } else if (isActiveDownload && activeDownloadPct != null) {
                  final pct = (activeDownloadPct * 100).toInt();
                  subtitle = Row(
                    children: [
                      Expanded(
                        child: LinearProgressIndicator(value: activeDownloadPct),
                      ),
                      SizedBox(width: 8.w),
                      Text('$pct%'),
                    ],
                  );
                } else if (isActiveDownload) {
                  subtitle = const LinearProgressIndicator(value: null);
                } else {
                  subtitle = const Text('Ready to download');
                }

                return ListTile(
                  key: ValueKey(item.id),
                  title: Text(item.fileName),
                  subtitle: subtitle,
                  trailing: isTransferring || isActiveDownload
                      ? const SizedBox.shrink()
                      : IconButton(
                          onPressed: isAnyDownloadBusy
                              ? null
                              : () {
                                  context.read<TransferBloc>().add(
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

  String? _activeDownloadId(TransferState state) {
    if (state is TransferLoading && state.isDownload) {
      return state.activeId;
    }
    if (state is TransferInProgress && state.isDownload) {
      return state.activeId;
    }
    return null;
  }

  double? _activeDownloadPct(TransferState state) {
    if (state is TransferInProgress && state.isDownload) {
      return state.pct;
    }
    return null;
  }
}
