import 'package:flutter/material.dart';

class SpectatorOverlay extends StatelessWidget {
  const SpectatorOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black.withOpacity(0.6),
      child: const Center(
        child: Text(
          '☠️ Bạn đã chết! Đang xem trận đấu...',
          style: TextStyle(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
