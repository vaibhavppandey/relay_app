import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:relay_app/src/feat/transfer/bloc/incoming/incoming_bloc.dart';
import 'package:relay_app/src/feat/transfer/bloc/transfer/transfer_bloc.dart';

class ProgressIndicatorWidget extends StatelessWidget {
  const ProgressIndicatorWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<TransferBloc, TransferState>(
      builder: (context, state) {
        if (state is TransferLoading && !state.isDownload) {
          return const LinearProgressIndicator(value: null);
        }

        if (state is TransferInProgress && !state.isDownload) {
          final pct = (state.pct * 100).toInt();
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              LinearProgressIndicator(value: state.pct),
              8.verticalSpace,
              Text('$pct%'),
            ],
          );
        }

        return BlocBuilder<IncomingBloc, IncomingState>(
          builder: (context, iState) {
            if (iState is! IncomingLoaded && iState is! IncomingFailure) {
              return const SizedBox.shrink();
            }

            final lst = iState is IncomingLoaded
                ? iState.lst
                : (iState as IncomingFailure).lst;
            final pending = lst.where((t) => t.status == 'pending').toList();
            final transferring = lst
                .where((t) => t.status == 'transferring')
                .toList();

            if (pending.isNotEmpty) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const LinearProgressIndicator(value: null),
                  8.verticalSpace,
                  const Text('Receiving...'),
                ],
              );
            }

            if (transferring.isNotEmpty) {
              final t = transferring.first;
              final pct = t.fileSize > 0
                  ? (t.progressBytes / t.fileSize).clamp(0.0, 1.0)
                  : 0.0;
              final txt = (pct * 100).toInt();
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  LinearProgressIndicator(value: pct),
                  8.verticalSpace,
                  Text('Receiving... $txt%'),
                ],
              );
            }

            return const SizedBox.shrink();
          },
        );
      },
    );
  }
}
