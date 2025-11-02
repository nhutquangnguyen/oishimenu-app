import 'package:flutter/material.dart';
import 'app_tokens.dart';

/// Reusable components following the design system
/// These components ensure consistency across the app
class AppButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final ButtonVariant variant;
  final ButtonSize size;
  final IconData? icon;
  final bool isLoading;

  const AppButton({
    super.key,
    required this.text,
    this.onPressed,
    this.variant = ButtonVariant.primary,
    this.size = ButtonSize.medium,
    this.icon,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SizedBox(
      height: _getHeight(),
      child: ElevatedButton(
        onPressed: isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: _getBackgroundColor(theme),
          foregroundColor: _getForegroundColor(theme),
          elevation: _getElevation(),
          padding: EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.sm,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSizing.radiusMD),
          ),
        ),
        child: isLoading
            ? SizedBox(
                width: AppSizing.iconSM,
                height: AppSizing.iconSM,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(_getForegroundColor(theme)),
                ),
              )
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (icon != null) ...[
                    Icon(icon, size: AppSizing.iconSM),
                    const SizedBox(width: AppSpacing.sm),
                  ],
                  Text(
                    text,
                    style: _getTextStyle(),
                  ),
                ],
              ),
      ),
    );
  }

  double _getHeight() {
    switch (size) {
      case ButtonSize.small:
        return AppSizing.buttonHeightSM;
      case ButtonSize.medium:
        return AppSizing.buttonHeightMD;
      case ButtonSize.large:
        return AppSizing.buttonHeightLG;
      case ButtonSize.extraLarge:
        return AppSizing.buttonHeightXL;
    }
  }

  Color _getBackgroundColor(ThemeData theme) {
    switch (variant) {
      case ButtonVariant.primary:
        return theme.colorScheme.primary;
      case ButtonVariant.secondary:
        return theme.colorScheme.secondary;
      case ButtonVariant.tertiary:
        return theme.colorScheme.tertiary;
      case ButtonVariant.error:
        return theme.colorScheme.error;
      case ButtonVariant.outline:
        return Colors.transparent;
    }
  }

  Color _getForegroundColor(ThemeData theme) {
    switch (variant) {
      case ButtonVariant.primary:
        return theme.colorScheme.onPrimary;
      case ButtonVariant.secondary:
        return theme.colorScheme.onSecondary;
      case ButtonVariant.tertiary:
        return theme.colorScheme.onTertiary;
      case ButtonVariant.error:
        return theme.colorScheme.onError;
      case ButtonVariant.outline:
        return theme.colorScheme.primary;
    }
  }

  double _getElevation() {
    switch (variant) {
      case ButtonVariant.outline:
        return AppElevation.none;
      default:
        return AppElevation.low;
    }
  }

  TextStyle _getTextStyle() {
    switch (size) {
      case ButtonSize.small:
        return AppTypography.body2.copyWith(fontWeight: AppTypography.semiBold);
      case ButtonSize.medium:
        return AppTypography.body1.copyWith(fontWeight: AppTypography.semiBold);
      case ButtonSize.large:
        return AppTypography.subtitle2.copyWith(fontWeight: AppTypography.semiBold);
      case ButtonSize.extraLarge:
        return AppTypography.subtitle1.copyWith(fontWeight: AppTypography.semiBold);
    }
  }
}

enum ButtonVariant { primary, secondary, tertiary, error, outline }
enum ButtonSize { small, medium, large, extraLarge }

/// App card component with consistent styling
class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets? padding;
  final double? elevation;
  final Color? backgroundColor;
  final VoidCallback? onTap;

  const AppCard({
    super.key,
    required this.child,
    this.padding,
    this.elevation,
    this.backgroundColor,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: elevation ?? AppElevation.low,
      color: backgroundColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSizing.radiusLG),
        side: BorderSide(
          color: Theme.of(context).colorScheme.outline.withValues(alpha:0.2),
          width: 1,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppSizing.radiusLG),
        child: Padding(
          padding: padding ?? AppSpacing.cardPadding,
          child: child,
        ),
      ),
    );
  }
}

/// Loading skeleton for shimmer effects
class AppSkeleton extends StatefulWidget {
  final double? width;
  final double? height;
  final double borderRadius;

  const AppSkeleton({
    super.key,
    this.width,
    this.height,
    this.borderRadius = AppSizing.radiusSM,
  });

  @override
  State<AppSkeleton> createState() => _AppSkeletonState();
}

class _AppSkeletonState extends State<AppSkeleton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );
    _animation = Tween<double>(
      begin: -2.0,
      end: 2.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    ));
    _controller.repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Container(
          width: widget.width,
          height: widget.height ?? AppSpacing.xl,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.borderRadius),
            gradient: LinearGradient(
              begin: Alignment(_animation.value - 1, 0),
              end: Alignment(_animation.value, 0),
              colors: [
                theme.colorScheme.surfaceContainerHighest,
                theme.colorScheme.surfaceContainerHighest.withValues(alpha:0.5),
                theme.colorScheme.surfaceContainerHighest,
              ],
            ),
          ),
        );
      },
    );
  }
}

/// App text field with consistent styling
class AppTextField extends StatelessWidget {
  final String? label;
  final String? hint;
  final String? initialValue;
  final ValueChanged<String>? onChanged;
  final TextInputType? keyboardType;
  final bool obscureText;
  final Widget? suffixIcon;
  final Widget? prefixIcon;
  final int? maxLines;
  final String? errorText;

  const AppTextField({
    super.key,
    this.label,
    this.hint,
    this.initialValue,
    this.onChanged,
    this.keyboardType,
    this.obscureText = false,
    this.suffixIcon,
    this.prefixIcon,
    this.maxLines = 1,
    this.errorText,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label != null) ...[
          Text(
            label!,
            style: AppTypography.body1.copyWith(
              fontWeight: AppTypography.medium,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
        ],
        TextFormField(
          initialValue: initialValue,
          onChanged: onChanged,
          keyboardType: keyboardType,
          obscureText: obscureText,
          maxLines: maxLines,
          style: AppTypography.body1,
          decoration: InputDecoration(
            hintText: hint,
            suffixIcon: suffixIcon,
            prefixIcon: prefixIcon,
            errorText: errorText,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppSizing.radiusMD),
              borderSide: BorderSide(
                color: Theme.of(context).colorScheme.outline,
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppSizing.radiusMD),
              borderSide: BorderSide(
                color: Theme.of(context).colorScheme.outline.withValues(alpha:0.5),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppSizing.radiusMD),
              borderSide: BorderSide(
                color: Theme.of(context).colorScheme.primary,
                width: 2,
              ),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppSizing.radiusMD),
              borderSide: BorderSide(
                color: Theme.of(context).colorScheme.error,
              ),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.md,
            ),
          ),
        ),
      ],
    );
  }
}

/// App icon button with proper touch targets
class AppIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onPressed;
  final String? tooltip;
  final Color? color;
  final double? size;
  final EdgeInsets? padding;

  const AppIconButton({
    super.key,
    required this.icon,
    this.onPressed,
    this.tooltip,
    this.color,
    this.size,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: AppSizing.touchTargetMin,
      height: AppSizing.touchTargetMin,
      child: IconButton(
        onPressed: onPressed,
        icon: Icon(
          icon,
          color: color,
          size: size ?? AppSizing.iconMD,
        ),
        tooltip: tooltip,
        padding: padding ?? EdgeInsets.zero,
      ),
    );
  }
}