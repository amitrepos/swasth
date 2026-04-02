import 'package:flutter/material.dart';

/// Max width for auth-style forms (readable line length on web/tablet).
const double kAuthFormMaxWidth = 440;

/// Scrollable body that centers the form and limits width on wide viewports.
class AuthFormScrollBody extends StatelessWidget {
  const AuthFormScrollBody({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16.0),
  });

  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: padding,
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: kAuthFormMaxWidth),
          child: child,
        ),
      ),
    );
  }
}

