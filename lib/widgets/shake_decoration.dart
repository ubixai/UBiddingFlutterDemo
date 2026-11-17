import 'package:flutter/material.dart';
import 'package:flutter/widget_previews.dart';

/// Pure decoration: no sensor access, gestures or advertising event reporting.
class ShakeDecoration extends StatelessWidget {
  const ShakeDecoration({super.key});
  @override
  Widget build(BuildContext context) => const Align(
    alignment: Alignment.center,
    child: DecoratedBox(
      decoration: BoxDecoration(
        color: Color(0x99000000),
        borderRadius: BorderRadius.all(Radius.circular(12)),
      ),
      child: Padding(
        padding: EdgeInsets.all(6),
        child: Icon(Icons.vibration, size: 24, color: Colors.white),
      ),
    ),
  );
}

@Preview(name: 'Shake decoration (no SDK)')
Widget shakeDecorationPreview() =>
    const SizedBox(width: 360, height: 240, child: ShakeDecoration());
