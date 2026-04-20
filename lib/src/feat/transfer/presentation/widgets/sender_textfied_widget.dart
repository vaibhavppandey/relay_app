import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:relay_app/src/core/native/native_file_picker.dart';
import 'package:relay_app/src/feat/transfer/bloc/transfer/transfer_bloc.dart';

class SenderTextFieldWidget extends StatefulWidget {
  const SenderTextFieldWidget({super.key});

  @override
  State<SenderTextFieldWidget> createState() => _SenderTextFieldWidgetState();
}

class _SenderTextFieldWidgetState extends State<SenderTextFieldWidget> {
  final textFieldController = TextEditingController();
  var isCodeValid = false;
  var isUp = false;
  var showDone = false;
  String? currentFilePath;

  @override
  void initState() {
    super.initState();
    textFieldController.addListener(_onCodeChanged);
  }

  @override
  void dispose() {
    textFieldController.removeListener(_onCodeChanged);
    textFieldController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final doneStyle = Theme.of(context).textTheme.bodyMedium?.copyWith(
      color: Theme.of(context).colorScheme.primary,
      fontSize: 14.sp,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: textFieldController,
          decoration: const InputDecoration(
            labelText: 'Recipient code',
            border: OutlineInputBorder(),
          ),
        ),
        8.verticalSpace,
        BlocBuilder<TransferBloc, TransferState>(
          builder: (context, state) {
            final isBusy =
                (state is TransferLoading && !state.isDownload) ||
                (state is TransferInProgress && !state.isDownload);
            final canSend = isCodeValid && !isBusy;
            return ElevatedButton(
              onPressed: !canSend
                  ? null
                  : () async {
                      final code = textFieldController.text.trim();
                      if (code.length != 6) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Recipient code must be 6 characters.',
                            ),
                          ),
                        );
                        return;
                      }

                      final files = await NativeFilePicker.pickFiles(
                        allowMultiple: true,
                      );
                      if (!context.mounted) {
                        return;
                      }

                      if (files.isEmpty) {
                        return;
                      }

                      setState(() {
                        isUp = true;
                        showDone = false;
                        currentFilePath = files.first.path;
                      });

                      context.read<TransferBloc>().add(
                        SendRequested(files: files, rCode: code),
                      );
                    },
              child: isBusy
                  ? const Text('Please wait...')
                  : const Text('Pick & Send Files'),
            );
          },
        ),
        8.verticalSpace,
        BlocBuilder<TransferBloc, TransferState>(
          builder: (context, state) {
            if (state is TransferLoading && !state.isDownload) {
              if (!isUp || state.activeId != currentFilePath) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (!mounted) {
                    return;
                  }
                  setState(() {
                    isUp = true;
                    showDone = false;
                    currentFilePath = state.activeId;
                  });
                });
              }
              return const LinearProgressIndicator(value: null);
            }

            if (state is TransferInProgress && !state.isDownload) {
              if (!isUp || state.activeId != currentFilePath) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (!mounted) {
                    return;
                  }
                  setState(() {
                    isUp = true;
                    showDone = false;
                    currentFilePath = state.activeId;
                  });
                });
              }

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

            if (state is TransferSuccess && isUp) {
              if (!showDone) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (!mounted) {
                    return;
                  }
                  setState(() {
                    showDone = true;
                    isUp = false;
                  });
                });
              }
              return Text('Upload complete', style: doneStyle);
            }

            if (state is TransferFailure && isUp) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (!mounted) {
                  return;
                }
                setState(() {
                  isUp = false;
                  showDone = false;
                });
              });
            }

            if (showDone) {
              return Text('Upload complete', style: doneStyle);
            }

            return const SizedBox.shrink();
          },
        ),
      ],
    );
  }

  void _onCodeChanged() {
    final next = textFieldController.text.trim().length == 6;
    if (next != isCodeValid) {
      setState(() {
        isCodeValid = next;
      });
    }
  }
}
