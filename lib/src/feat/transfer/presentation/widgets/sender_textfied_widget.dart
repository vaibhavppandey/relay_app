import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:relay_app/src/feat/transfer/bloc/transfer/transfer_bloc.dart';

class SenderTextFieldWidget extends StatefulWidget {
  const SenderTextFieldWidget({super.key});

  @override
  State<SenderTextFieldWidget> createState() => _SenderTextFieldWidgetState();
}

class _SenderTextFieldWidgetState extends State<SenderTextFieldWidget> {
  final textFieldController = TextEditingController();
  var isCodeValid = false;

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
                state is TransferLoading || state is TransferInProgress;
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

                      final res = await FilePicker.platform.pickFiles(
                        allowMultiple: true,
                      );
                      if (!context.mounted) {
                        return;
                      }
                      if (res == null) {
                        return;
                      }

                      final files = res.paths
                          .whereType<String>()
                          .map((path) => File(path))
                          .toList();

                      if (files.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('No files selected.')),
                        );
                        return;
                      }

                      if (!context.mounted) {
                        return;
                      }
                      context.read<TransferBloc>().add(
                        SendRequested(files: files, rCode: code),
                      );
                    },
              child: isBusy
                  ? Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 16.r,
                          height: 16.r,
                          child: const CircularProgressIndicator(
                            strokeWidth: 2,
                          ),
                        ),
                        8.horizontalSpace,
                        const Text('Please wait...'),
                      ],
                    )
                  : const Text('Pick & Send Files'),
            );
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
