import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter/services.dart';
import 'package:relay_app/src/core/native/native_file_picker.dart';
import 'package:relay_app/src/feat/transfer/bloc/transfer/transfer_bloc.dart';

class SenderTextFieldWidget extends StatefulWidget {
  const SenderTextFieldWidget({super.key});

  @override
  State<SenderTextFieldWidget> createState() => _SenderTextFieldWidgetState();
}

class _SenderTextFieldWidgetState extends State<SenderTextFieldWidget> {
  final textFieldController = TextEditingController();
  final ValueNotifier<bool> _isCodeValid = ValueNotifier(false);
  final ValueNotifier<bool> _showDone = ValueNotifier(false);

  @override
  void initState() {
    super.initState();
    textFieldController.addListener(_onCodeChanged);
  }

  @override
  void dispose() {
    textFieldController.removeListener(_onCodeChanged);
    textFieldController.dispose();
    _isCodeValid.dispose();
    _showDone.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final doneStyle = Theme.of(context).textTheme.bodyMedium?.copyWith(
      color: Theme.of(context).colorScheme.primary,
      fontSize: 14.sp,
    );

    return BlocListener<TransferBloc, TransferState>(
      listenWhen: (previous, current) {
        final uploadWasActive = _isActiveUploadState(previous);
        final terminalState = current is TransferSuccess || current is TransferFailure;
        return uploadWasActive && terminalState;
      },
      listener: (context, state) {
        if (state is TransferSuccess) {
          _showDone.value = true;
        }

        if (state is TransferFailure) {
          _showDone.value = false;
        }
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: textFieldController,
            textCapitalization: TextCapitalization.characters,
            keyboardType: TextInputType.visiblePassword,
            enableSuggestions: false,
            autocorrect: false,
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9]')),
              LengthLimitingTextInputFormatter(6),
              _UpperCaseTextFormatter(),
            ],
            decoration: const InputDecoration(
              labelText: 'Recipient code',
              border: OutlineInputBorder(),
            ),
          ),
          8.verticalSpace,
          ValueListenableBuilder<bool>(
            valueListenable: _isCodeValid,
            builder: (context, isCodeValid, _) {
              return BlocBuilder<TransferBloc, TransferState>(
                builder: (context, state) {
                  final isBusy =
                      state is TransferLoading || state is TransferInProgress;
                  final canSend = isCodeValid && !isBusy;
                  return ElevatedButton(
                    onPressed: !canSend
                        ? null
                        : () async {
                            final code = textFieldController.text
                                .trim()
                                .toUpperCase();
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

                            _showDone.value = false;

                            context.read<TransferBloc>().add(
                              SendRequested(files: files, rCode: code),
                            );
                          },
                    child: isBusy
                        ? const Text('Please wait...')
                        : const Text('Pick & Send Files'),
                  );
                },
              );
            },
          ),
          8.verticalSpace,
          BlocBuilder<TransferBloc, TransferState>(
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

              return ValueListenableBuilder<bool>(
                valueListenable: _showDone,
                builder: (context, showDone, _) {
                  if (showDone) {
                    return Text('Upload complete', style: doneStyle);
                  }
                  return const SizedBox.shrink();
                },
              );
            },
          ),
        ],
      ),
    );
  }

  void _onCodeChanged() {
    final next = textFieldController.text.trim().length == 6;
    if (next != _isCodeValid.value) {
      _isCodeValid.value = next;
    }
  }

  bool _isActiveUploadState(TransferState state) {
    if (state is TransferLoading) {
      return !state.isDownload;
    }
    if (state is TransferInProgress) {
      return !state.isDownload;
    }
    return false;
  }
}

class _UpperCaseTextFormatter extends TextInputFormatter {
  const _UpperCaseTextFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    return newValue.copyWith(text: newValue.text.toUpperCase());
  }
}
