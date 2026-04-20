import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:relay_app/src/core/native/native_file_picker.dart';
import 'package:relay_app/src/feat/nearby/bloc/nearby_bloc.dart';
import 'package:relay_app/src/feat/nearby/data/repo/nearby_repository.dart';
import 'package:relay_app/src/feat/nearby/presentation/widgets/nearby_bottom_sheet.dart';
import 'package:relay_app/src/feat/onboarding/bloc/onboarding_bloc.dart';
import 'package:relay_app/src/feat/transfer/bloc/incoming/incoming_bloc.dart';
import 'package:relay_app/src/feat/transfer/bloc/transfer/transfer_bloc.dart';
import 'package:relay_app/src/feat/transfer/presentation/widgets/downloaded_files_widget.dart';
import 'package:relay_app/src/feat/transfer/presentation/widgets/incoming_files_widget.dart';
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
    context.read<NearbyBloc>();
    context.read<IncomingBloc>().add(StartListening(myCode: _myCode));
    context.read<TransferBloc>().add(const RecoveryRequested());
    if (_myCode.isNotEmpty) {
      unawaited(context.read<NearbyRepository>().startBroadcasting(_myCode));
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _myCode.isNotEmpty) {
      context.read<IncomingBloc>().add(StartListening(myCode: _myCode));
    }
  }

  @override
  void dispose() {
    unawaited(context.read<NearbyRepository>().stopDiscoveryScan());
    unawaited(context.read<NearbyRepository>().stopBroadcasting());
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Relay'),
          actions: [
            Builder(
              builder: (tabContext) => IconButton(
                onPressed: () async {
                  final code = await showModalBottomSheet<String>(
                    context: tabContext,
                    builder: (c) => NearbyBottomSheet(myCode: _myCode),
                  );
                  if (!mounted || !tabContext.mounted) {
                    return;
                  }
                  if (code == null || code.isEmpty) {
                    return;
                  }

                  final ctrl = DefaultTabController.of(tabContext);
                  ctrl.animateTo(0);

                  await Future<void>.delayed(const Duration(milliseconds: 250));
                  if (!mounted || !tabContext.mounted) {
                    return;
                  }

                  final files = await NativeFilePicker.pickFiles(
                    allowMultiple: true,
                  );
                  if (!mounted || !tabContext.mounted || files.isEmpty) {
                    return;
                  }

                  tabContext.read<TransferBloc>().add(
                    SendRequested(files: files, rCode: code),
                  );
                },
                icon: const Icon(Icons.wifi_tethering),
              ),
            ),
          ],
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Send'),
              Tab(text: 'Pending'),
              Tab(text: 'Saved'),
            ],
          ),
        ),
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
            child: TabBarView(
              children: [
                Padding(
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
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(color: scheme.onSecondaryContainer),
                          ),
                        ),
                      ),
                      12.verticalSpace,
                      const SenderTextFieldWidget(),
                    ],
                  ),
                ),
                Padding(
                  padding: EdgeInsets.all(16.w),
                  child: const IncomingFilesWidget(),
                ),
                Padding(
                  padding: EdgeInsets.all(16.w),
                  child: const DownloadedFilesWidget(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
