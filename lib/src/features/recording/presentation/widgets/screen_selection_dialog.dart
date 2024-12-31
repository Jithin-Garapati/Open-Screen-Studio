import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/screen_info.dart';
import '../controllers/recording_controller.dart';
import '../../../../services/screen_selector_service.dart';

final availableWindowsProvider = FutureProvider<List<ScreenInfo>>((ref) async {
  return ScreenSelectorService.getWindows();
});

class ScreenSelectionDialog extends ConsumerWidget {
  const ScreenSelectionDialog({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final windowsAsync = ref.watch(availableWindowsProvider);
    final currentScreen = ref.watch(recordingControllerProvider).selectedScreen;

    return Dialog(
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 600, maxHeight: 600),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Select Window',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 24),
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      windowsAsync.when(
                        data: (windows) {
                          print('Loaded ${windows.length} windows'); // Debug print
                          if (windows.isEmpty) {
                            return const Center(
                              child: Padding(
                                padding: EdgeInsets.all(16.0),
                                child: Text('No windows found'),
                              ),
                            );
                          }
                          return Column(
                            children: windows.map((window) {
                              final isSelected = currentScreen?.handle == window.handle;
                              return _buildOption(
                                context,
                                screen: window,
                                isSelected: isSelected,
                                onSelect: () {
                                  ref.read(recordingControllerProvider.notifier).setScreen(window);
                                  Navigator.of(context).pop();
                                },
                              );
                            }).toList(),
                          );
                        },
                        loading: () => const Center(child: CircularProgressIndicator()),
                        error: (error, stack) {
                          print('Error loading windows: $error'); // Debug print
                          return Center(
                            child: Text(
                              'Error loading windows: $error',
                              style: TextStyle(color: Theme.of(context).colorScheme.error),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOption(
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
                  Icons.window_rounded,
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
                        screen.windowTitle ?? 'Unknown Window',
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: isSelected
                              ? theme.colorScheme.primary
                              : theme.colorScheme.onSurface,
                          fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                        ),
                      ),
                      Text(
                        '${screen.width}x${screen.height}',
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