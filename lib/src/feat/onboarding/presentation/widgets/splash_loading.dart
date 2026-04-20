import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class SplashLoadingWidget extends StatelessWidget {
  const SplashLoadingWidget({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(),
          12.verticalSpace,
          Text(message, style: textTheme.bodyMedium),
        ],
      ),
    );
  }
}
