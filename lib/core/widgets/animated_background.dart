import 'package:flutter/material.dart';

class AnimatedBackground extends StatefulWidget {
  final Widget child;
  const AnimatedBackground({super.key, required this.child});

  @override
  State<AnimatedBackground> createState() => _AnimatedBackgroundState();
}

class _AnimatedBackgroundState extends State<AnimatedBackground>
    with SingleTickerProviderStateMixin {
  late AnimationController _bgAnimCtrl;

  @override
  void initState() {
    super.initState();
    _bgAnimCtrl =
        AnimationController(vsync: this, duration: const Duration(seconds: 10))
          ..repeat(reverse: true);
  }

  @override
  void dispose() {
    _bgAnimCtrl.dispose();
    super.dispose();
  }

  Widget _buildOrb(Color color, double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [color, Colors.transparent],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        RepaintBoundary(
          child: Stack(
            children: [
              Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF0A0A14), Color(0xFF0D0820), Color(0xFF0A1428)],
                  ),
                ),
              ),
              AnimatedBuilder(
                animation: _bgAnimCtrl,
                builder: (ctx, child) {
                  return Stack(
                    children: [
                      Positioned(
                        top: -50 + (_bgAnimCtrl.value * 30),
                        right: -100 - (_bgAnimCtrl.value * 20),
                        child: _buildOrb(const Color(0xFF7C3AED).withOpacity(0.4), 350),
                      ),
                      Positioned(
                        bottom: -100 + (_bgAnimCtrl.value * 40),
                        left: -50 - (_bgAnimCtrl.value * 20),
                        child: _buildOrb(const Color(0xFF0891B2).withOpacity(0.3), 400),
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
        RepaintBoundary(
          child: widget.child,
        ),
      ],
    );
  }
}
