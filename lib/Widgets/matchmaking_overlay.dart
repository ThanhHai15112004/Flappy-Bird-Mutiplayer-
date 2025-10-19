import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class MatchmakingOverlay extends StatefulWidget {
  final ValueListenable<List<String>> playersListenable;
  final ValueListenable<bool> joinedListenable;
  final VoidCallback onCancel;
  final VoidCallback onReady;
  final VoidCallback? onCancelReady;

  const MatchmakingOverlay({
    super.key,
    required this.playersListenable,
    required this.joinedListenable,
    required this.onCancel,
    required this.onReady,
    this.onCancelReady,
  });

  @override
  State<MatchmakingOverlay> createState() => _MatchmakingOverlayState();
}

class _MatchmakingOverlayState extends State<MatchmakingOverlay> {
  bool _isReady = false;

  void _handleCancel() {
    if (_isReady) setState(() => _isReady = false);
    widget.onCancel();
  }

  void _toggleReady(bool joined) {
    if (joined) return;

    setState(() => _isReady = !_isReady);
    _isReady ? widget.onReady() : widget.onCancelReady?.call();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(16),
      child: Card(
        color: const Color(0xFF2E7D32).withOpacity(0.9),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: Colors.white.withOpacity(0.7), width: 2),
        ),
        child: Container(
          width: double.maxFinite,
          height: MediaQuery.of(context).size.height * 0.7,
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              _buildHeader(),
              const SizedBox(height: 10),
              _buildPlayersList(),
              const SizedBox(height: 20),
              _buildActionButtons(),
            ],
          ),
        ),
      ),
    );
  }

  // Header với title và close button
  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Text(
          'TÌM TRẬN',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: Colors.white,
            shadows: [Shadow(blurRadius: 5, color: Colors.black54)],
          ),
        ),
        IconButton(
          icon: const Icon(Icons.close, color: Colors.white, size: 30),
          onPressed: _handleCancel,
          tooltip: 'Thoát lobby',
        ),
      ],
    );
  }

  // Danh sách người chơi
  Widget _buildPlayersList() {
    return ValueListenableBuilder<List<String>>(
      valueListenable: widget.playersListenable,
      builder: (context, players, _) {
        final realPlayers = players.where((p) => p != 'Đang tìm đối thủ...').toList();
        
        return Expanded(
          child: Column(
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '${realPlayers.length} người đã tham gia',
                  style: const TextStyle(fontSize: 16, color: Colors.white70),
                ),
              ),
              const Divider(color: Colors.white30),
              Expanded(child: _buildPlayersGrid(realPlayers)),
            ],
          ),
        );
      },
    );
  }

  // Grid danh sách người chơi
  Widget _buildPlayersGrid(List<String> players) {
    final screenW = MediaQuery.of(context).size.width;
    final cols = ((screenW / 180).floor()).clamp(2, 4).toInt();
    final aspect = screenW < 360 ? 2.0 : (screenW < 480 ? 2.2 : 2.5);

    return GridView.builder(
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: cols,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: aspect,
      ),
      itemCount: players.length,
      itemBuilder: (context, index) => _buildPlayerCard(players[index]),
    );
  }

  // Card từng người chơi
  Widget _buildPlayerCard(String playerName) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.2),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white54),
      ),
      child: Row(
        children: [
          Image.asset(
            'assets/images/bird.png',
            width: 24,
            height: 24,
            errorBuilder: (_, __, ___) => const Icon(
              Icons.image_not_supported,
              size: 18,
              color: Colors.white54,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              playerName,
              style: const TextStyle(color: Colors.white, fontSize: 14),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  // Action buttons (Hủy và Sẵn sàng)
  Widget _buildActionButtons() {
    return ValueListenableBuilder<bool>(
      valueListenable: widget.joinedListenable,
      builder: (context, joined, _) {
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildCancelButton(),
            _buildReadyButton(joined),
          ],
        );
      },
    );
  }

  // Button Hủy
  Widget _buildCancelButton() {
    return ElevatedButton.icon(
      onPressed: _handleCancel,
      icon: const Icon(Icons.close),
      label: const Text('HỦY'),
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.red.shade600,
        padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 12),
      ),
    );
  }

  // Button Sẵn sàng
  Widget _buildReadyButton(bool joined) {
    final bgColor = _isReady
        ? Colors.green.shade800.withOpacity(0.6)
        : Colors.green.shade600;

    return ElevatedButton.icon(
      onPressed: joined ? null : () => _toggleReady(joined),
      icon: Icon(_isReady ? Icons.check_circle : Icons.sports_esports),
      label: Text(_isReady ? 'ĐÃ READY' : 'SẴN SÀNG'),
      style: ElevatedButton.styleFrom(
        backgroundColor: joined ? Colors.green.shade900 : bgColor,
        disabledBackgroundColor: Colors.green.shade900,
        padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 12),
      ),
    );
  }
}
