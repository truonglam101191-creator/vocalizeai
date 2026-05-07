import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class BaseButton extends StatelessWidget {
  final String text;
  final IconData icon;
  final bool isLoading;
  final VoidCallback? onPressed;
  final Gradient gradient;

  const BaseButton({
    super.key,
    required this.text,
    required this.icon,
    this.isLoading = false,
    required this.onPressed,
    required this.gradient,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 56,
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: onPressed == null ? null : gradient,
        color: onPressed == null ? Colors.white.withOpacity(0.1) : null,
        borderRadius: BorderRadius.circular(16),
        boxShadow: onPressed == null
            ? []
            : [
                BoxShadow(
                  color: gradient.colors.first.withOpacity(0.4),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                )
              ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(16),
          child: Center(
            child: isLoading
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2.5))
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(icon,
                          color: onPressed == null ? Colors.white54 : Colors.white,
                          size: 22),
                      const SizedBox(width: 10),
                      Text(
                        text,
                        style: GoogleFonts.inter(
                          color: onPressed == null ? Colors.white54 : Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}
