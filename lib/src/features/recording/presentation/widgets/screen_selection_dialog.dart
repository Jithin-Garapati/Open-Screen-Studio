import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/screen_info.dart';
import '../controllers/recording_controller.dart';
import '../../../../services/screen_selector_service.dart';

final availableScreensProvider = FutureProvider<List<ScreenInfo>>((ref) async {
  final displays = await ScreenSelectorService.getDisplays();
  return displays.map((display) => ScreenInfo.fromDisplayInfo(display)).toList();
});

class ScreenSelectionDialog extends ConsumerWidget {
  const ScreenSelectionDialog({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final screensAsync = ref.watch(availableScreensProvider);
    final currentScreen = ref.watch(recordingControllerProvider).selectedScreen;

    return Dialog(
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Select Screen',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 24),
            screensAsync.when(
              data: (screens) => Column(
                children: screens.map((screen) {
                  final isSelected = currentScreen?.handle == screen.handle;
                  return _buildScreenOption(
                    context,
                    screen: screen,
                    isSelected: isSelected,
                    onSelect: () {
                      ref.read(recordingControllerProvider.notifier).setScreen(screen);
                      Navigator.of(context).pop();
                    },
                  );
                }).toList(),
              ),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stack) => Center(
                child: Text(
                  'Error loading screens: $error',
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScreenOption(
    BuildContext context, {
    required ScreenInfo screen,
    required bool isSelected,
    required VoidCallback onSelect,
  }) {
    final theme = Theme.of(context);
    
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onSelect,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isSelected
                  ? theme.colorScheme.primary.withOpacity(0.1)
                  : Colors.transparent,
              border: Border.all(
                color: isSelected
                    ? theme.colorScheme.primary
                    : theme.colorScheme.onSurface.withOpacity(0.1),
                width: 1,
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.desktop_windows_rounded,
                  color: isSelected
                      ? theme.colorScheme.primary
                      : theme.colorScheme.onSurface.withOpacity(0.7),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        screen.name,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: isSelected
                              ? theme.colorScheme.primary
                              : theme.colorScheme.onSurface,
                          fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                        ),
                      ),
                      Text(
                        '${screen.width}x${screen.height}${screen.isPrimary ? ' (Primary)' : ''}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface.withOpacity(0.7),
                        ),
                      ),
                    ],
                  ),
                ),
                if (isSelected)
                  Icon(
                    Icons.check_circle_rounded,
                    color: theme.colorScheme.primary,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
} 