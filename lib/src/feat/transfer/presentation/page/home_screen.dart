import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:relay_app/src/feat/onboarding/bloc/onboarding_bloc.dart';
import 'package:relay_app/src/feat/transfer/bloc/transfer_bloc.dart';
import 'package:relay_app/src/feat/transfer/presentation/widgets/incoming_view.dart';
import 'package:relay_app/src/feat/transfer/presentation/widgets/progress_view.dart';
import 'package:relay_app/src/feat/transfer/presentation/widgets/sender_view.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late final String _myCode;

  @override
  void initState() {
    super.initState();
    final state = context.read<OnboardingBloc>().state;
    _myCode = state is OnboardingSuccess ? state.shortCode : '';
    context.read<TransferBloc>().add(IncomingListened(myCode: _myCode));
  }

  @override
  Widget build(BuildContext ctx) {
    return Scaffold(
      appBar: AppBar(title: const Text('Relay')),
      body: BlocListener<TransferBloc, TransferState>(
        listener: (ctx, state) {
          if (state is TransferFailure) {
            ScaffoldMessenger.of(
              ctx,
            ).showSnackBar(SnackBar(content: Text(state.msg)));
          }

          if (state is TransferSuccess) {
            ScaffoldMessenger.of(
              ctx,
            ).showSnackBar(const SnackBar(content: Text('Success')));
            ctx.read<TransferBloc>().add(const TransferReset());
          }
        },
        child: SafeArea(
          child: Padding(
            padding: EdgeInsets.all(16.w),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.all(12.w),
                  color: Colors.blueGrey.shade50,
                  child: Text(
                    'Your code: $_myCode',
                    style: Theme.of(ctx).textTheme.titleLarge,
                  ),
                ),
                12.verticalSpace,
                const SenderView(),
                12.verticalSpace,
                Text('Incoming', style: Theme.of(ctx).textTheme.titleMedium),
                8.verticalSpace,
                const IncomingView(),
                12.verticalSpace,
                const ProgressView(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
