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

  @override
  void dispose() {
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
        ElevatedButton(
          onPressed: () async {
            final code = textFieldController.text.trim();
            if (code.isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Enter recipient code.')),
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
          child: const Text('Pick & Send Files'),
        ),
      ],
    );
  }
}
