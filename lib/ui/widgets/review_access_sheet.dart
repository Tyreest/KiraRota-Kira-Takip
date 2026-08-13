import 'package:flutter/material.dart';

/// Review Access bottom sheet için sistem nav + klavye inset sarmalayıcı.
///
/// [SafeArea] (maintainBottomViewPadding) 3-button / gesture nav alanını korur;
/// [viewInsets.bottom] klavye altında kalmayı engeller; dar yükseklikte scroll.
@visibleForTesting
class ReviewAccessSheetScaffold extends StatelessWidget {
  const ReviewAccessSheetScaffold({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final keyboardInset = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: keyboardInset),
      child: SafeArea(
        maintainBottomViewPadding: true,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 20),
          child: child,
        ),
      ),
    );
  }
}
