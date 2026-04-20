import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:relay_app/src/feat/onboarding/bloc/onboarding_bloc.dart';
import 'package:relay_app/src/feat/transfer/bloc/incoming/incoming_bloc.dart';
import 'package:relay_app/src/feat/transfer/bloc/transfer/transfer_bloc.dart';
import 'package:relay_app/src/feat/transfer/presentation/widgets/downloaded_files_widget.dart';
import 'package:relay_app/src/feat/transfer/presentation/widgets/incoming_files_widget.dart';
import 'package:relay_app/src/feat/transfer/presentation/widgets/progress_indicator_widget.dart';
import 'package:relay_app/src/feat/transfer/presentation/widgets/sender_textfied_widget.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  late final String _myCode;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final state = context.read<OnboardingBloc>().state;
    _myCode = state is OnboardingSuccess ? state.shortCode : '';
    context.read<IncomingBloc>().add(StartListening(myCode: _myCode));
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _myCode.isNotEmpty) {
      context.read<IncomingBloc>().add(StartListening(myCode: _myCode));
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Relay')),
      body: MultiBlocListener(
        listeners: [
          BlocListener<IncomingBloc, IncomingState>(
            listener: (context, state) {
              if (state is IncomingFailure) {
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(SnackBar(content: Text(state.msg)));
              }
            },
          ),
          BlocListener<TransferBloc, TransferState>(
            listener: (context, state) {
              if (state is TransferFailure) {
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(SnackBar(content: Text(state.msg)));
              }

              if (state is TransferSuccess) {
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(const SnackBar(content: Text('Success')));
                context.read<TransferBloc>().add(const TransferReset());
              }
            },
          ),
        ],
        child: SafeArea(
          child: Padding(
            padding: EdgeInsets.all(16.w),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Card(
                  margin: EdgeInsets.zero,
                  child: Container(
                    width: double.infinity,
                    padding: EdgeInsets.all(12.w),
                    decoration: BoxDecoration(
                      color: scheme.secondaryContainer,
                      borderRadius: BorderRadius.circular(12.r),
                    ),
                    child: Text(
                      'Your code: $_myCode',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: scheme.onSecondaryContainer,
                      ),
                    ),
                  ),
                ),
                12.verticalSpace,
                const SenderTextFieldWidget(),
                12.verticalSpace,
                Text(
                  'Incoming',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                8.verticalSpace,
                const IncomingFilesWidget(),
                12.verticalSpace,
                Text(
                  'Downloaded',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                8.verticalSpace,
                const DownloadedFilesWidget(),
                12.verticalSpace,
                const ProgressIndicatorWidget(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
