import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class ActionableErrorWidget extends StatelessWidget {
  const ActionableErrorWidget({
    required this.errorMessage,
    required this.onRetry,
    super.key,
  });

  final String errorMessage;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Center(
      child: Padding(
        padding: EdgeInsets.all(24.w),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, color: Colors.red, size: 48.r),
            12.verticalSpace,
            Text(
              errorMessage,
              textAlign: TextAlign.center,
              style: textTheme.bodyMedium,
            ),
            16.verticalSpace,
            ElevatedButton(
              onPressed: onRetry,
              child: Text('Retry', style: textTheme.labelLarge),
            ),
          ],
        ),
      ),
    );
  }
}
