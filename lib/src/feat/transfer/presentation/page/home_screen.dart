import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:nsd/nsd.dart';
import 'package:relay_app/src/core/native/native_file_picker.dart';
import 'package:relay_app/src/feat/nearby/data/repo/nearby_repository.dart';
import 'package:relay_app/src/feat/nearby/presentation/widgets/nearby_bottom_sheet.dart';
import 'package:relay_app/src/feat/transfer/bloc/incoming/incoming_bloc.dart';
import 'package:relay_app/src/feat/transfer/bloc/transfer/transfer_bloc.dart';
import 'package:relay_app/src/feat/transfer/presentation/widgets/downloaded_files_widget.dart';
import 'package:relay_app/src/feat/transfer/presentation/widgets/incoming_files_widget.dart';
import 'package:relay_app/src/feat/transfer/presentation/widgets/sender_textfied_widget.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({required this.myCode, super.key});

  final String myCode;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  late final IncomingBloc _incomingBloc;
  late final TransferBloc _transferBloc;
  late final NearbyRepository _nearbyRepository;
  StreamSubscription? _nearbyEventSub;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _incomingBloc = context.read<IncomingBloc>();
    _transferBloc = context.read<TransferBloc>();
    _nearbyRepository = context.read<NearbyRepository>();

    _incomingBloc.add(StartListening(myCode: widget.myCode));
    _transferBloc.add(const RecoveryRequested());
    if (widget.myCode.isNotEmpty) {
      unawaited(_nearbyRepository.startBroadcasting(widget.myCode));
    }

    _nearbyEventSub = _nearbyRepository.events.listen((event) {
      if (event == NearbyEvent.fileReceived) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('file downloaded successfully')),
        );
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && widget.myCode.isNotEmpty) {
      _incomingBloc.add(StartListening(myCode: widget.myCode));
    }
  }

  @override
  void dispose() {
    unawaited(_nearbyRepository.stopDiscoveryScan());
    unawaited(_nearbyRepository.stopBroadcasting());
    _nearbyEventSub?.cancel();
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
              builder: (tabContext) => BlocBuilder<TransferBloc, TransferState>(
                bloc: _transferBloc,
                builder: (context, transferState) {
                  final busy = _isTransferBusy(transferState);
                  return IconButton(
                    onPressed: busy
                        ? null
                        : () async {
                            final target = await showModalBottomSheet<Service>(
                              context: tabContext,
                              builder: (c) =>
                                  NearbyBottomSheet(myCode: widget.myCode),
                            );
                            if (!mounted || !tabContext.mounted) {
                              return;
                            }
                            if (target == null) {
                              return;
                            }

                            final ctrl = DefaultTabController.of(tabContext);
                            ctrl.animateTo(0);

                            await Future<void>.delayed(
                              const Duration(milliseconds: 250),
                            );
                            if (!mounted || !tabContext.mounted) {
                              return;
                            }

                            final files = await NativeFilePicker.pickFiles(
                              allowMultiple: true,
                            );
                            if (!mounted ||
                                !tabContext.mounted ||
                                files.isEmpty) {
                              return;
                            }

                            _transferBloc.add(
                              SendNearbyRequested(files: files, target: target),
                            );
                          },
                    icon: const Icon(Icons.wifi_tethering),
                  );
                },
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
                  final msg = state.isDownload
                      ? 'file downloaded successfully'
                      : 'file transferred successfully';
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text(msg)));
                  _transferBloc.add(const TransferReset());
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
                            'Your code: ${widget.myCode}',
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

  bool _isTransferBusy(TransferState state) {
    return state is TransferLoading || state is TransferInProgress;
  }
}
