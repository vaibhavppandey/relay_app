import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:relay_app/src/feat/transfer/bloc/transfer_bloc.dart';

class ProgressIndicatorWidget extends StatelessWidget {
  const ProgressIndicatorWidget({super.key});

  @override
  Widget build(BuildContext ctx) {
    return BlocBuilder<TransferBloc, TransferState>(
      builder: (ctx, state) {
        if (state is TransferLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        if (state is TransferInProgress) {
          final pct = (state.pct * 100).toInt();
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Transferring... $pct%'),
              8.verticalSpace,
              LinearProgressIndicator(value: state.pct),
              8.verticalSpace,
              ElevatedButton(
                onPressed: () {
                  ctx.read<TransferBloc>().add(const TransferCancelled());
                },
                child: const Text('Cancel'),
              ),
            ],
          );
        }

        return const SizedBox.shrink();
      },
    );
  }
}
