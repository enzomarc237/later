import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:macos_ui/macos_ui.dart';

import '../models/models.dart';
import '../providers/providers.dart';
import 'home_page.dart';
import 'settings_page.dart';

class MainView extends ConsumerStatefulWidget {
  const MainView({super.key});

  @override
  ConsumerState<MainView> createState() => _MainViewState();
}

class _MainViewState extends ConsumerState<MainView> {
  int _pageIndex = 0;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final appState = ref.watch(appNotifier);
    final filteredCategories = appState.categories.where((category) => _searchQuery.isEmpty || category.name.toLowerCase().contains(_searchQuery.toLowerCase())).toList();
    final theme = MacosTheme.of(context);

    return MacosWindow(
      backgroundColor: Colors.transparent,
      sidebar: Sidebar(
        decoration: BoxDecoration(
          color: theme.canvasColor,
        ),
        minWidth: 200,
        // Move All URLs button to the top of the sidebar
        top: Padding(
          padding: const EdgeInsets.all(12.0),
          child: PushButton(
            controlSize: ControlSize.large,
            secondary: true,
            color: appState.selectedCategoryId == null ? theme.primaryColor : null,
            onPressed: () {
              // Use the explicit clearSelectedCategory method to ensure category is unselected
              ref.read(appNotifier.notifier).clearSelectedCategory();
              // Force a rebuild to ensure UI updates
              setState(() {
                _pageIndex = 0; // Switch to HomePage
              });
              // Debug print to verify the function is called
              debugPrint('All URLs button clicked, clearing filters');
            },
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                MacosIcon(
                  CupertinoIcons.doc_text_search,
                  color: appState.selectedCategoryId == null
                      ? theme.primaryColor
                      : theme.brightness == Brightness.dark
                          ? MacosColors.systemGrayColor
                          : MacosColors.systemGrayColor,
                  size: 22.0,
                ),
                const SizedBox(width: 8.0),
                Text(
                  'All URLs',
                  style: theme.typography.body.copyWith(
                    fontWeight: FontWeight.bold,
                    color: appState.selectedCategoryId == null
                        ? theme.primaryColor
                        : theme.brightness == Brightness.dark
                            ? MacosColors.systemGrayColor
                            : MacosColors.systemGrayColor,
                  ),
                ),
              ],
            ),
          ),
        ),
        builder: (context, scrollController) => Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: MacosSearchField(
                placeholder: 'Search categories',
                controller: _searchController,
                onChanged: (value) {
                  setState(() {
                    _searchQuery = value;
                  });
                },
              ),
            ),
            const SizedBox(height: 8.0),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Text(
                'Categories',
                style: theme.typography.subheadline.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.brightness == Brightness.dark ? MacosColors.systemGrayColor : MacosColors.systemGrayColor,
                ),
              ),
            ),
            const SizedBox(height: 8.0),
            Expanded(
              child: appState.categories.isEmpty
                  ? Center(
                      child: Text(
                        'No categories yet',
                        style: theme.typography.body,
                      ),
                    )
                  : ListView.builder(
                      controller: scrollController,
                      itemCount: filteredCategories.length,
                      itemBuilder: (context, index) {
                        final category = filteredCategories[index];
                        final isSelected = category.id == appState.selectedCategoryId;
                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 2.0),
                          child: Container(
                            decoration: BoxDecoration(
                              color: isSelected ? theme.primaryColor.withOpacity(0.2) : Colors.transparent,
                              borderRadius: BorderRadius.circular(8.0),
                            ),
                            child: GestureDetector(
                              onSecondaryTapUp: (details) {
                                _showCategoryContextMenu(context, category, details.globalPosition);
                              },
                              child: Row(
                                children: [
                                  Expanded(
                                    child: MacosListTile(
                                      leading: MacosIcon(
                                        category.icon,
                                        color: theme.brightness == Brightness.dark ? Colors.white : Colors.black,
                                      ),
                                      title: Text(
                                        category.name,
                                        style: theme.typography.body,
                                      ),
                                      onClick: () {
                                        ref.read(appNotifier.notifier).selectCategory(category.id);
                                        // Switch to HomePage when a category is selected
                                        setState(() => _pageIndex = 0);
                                      },
                                    ),
                                  ),
                                  MacosIconButton(
                                    icon: MacosIcon(
                                      CupertinoIcons.ellipsis,
                                      size: 16,
                                      color: theme.brightness == Brightness.dark ? Colors.white : Colors.black,
                                    ),
                                    padding: const EdgeInsets.only(right: 8.0),
                                    onPressed: () {
                                      _showCategoryContextMenu(
                                        context,
                                        category,
                                        Offset(
                                          MediaQuery.of(context).size.width / 2,
                                          MediaQuery.of(context).size.height / 2,
                                        ),
                                      );
                                    },
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
            Divider(
              height: 24.0,
              thickness: 1.0,
              color: theme.brightness == Brightness.dark ? Colors.grey.shade800 : Colors.grey.shade300,
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 2.0),
              child: Container(
                decoration: BoxDecoration(
                  color: _pageIndex == 1 ? theme.primaryColor.withOpacity(0.2) : Colors.transparent,
                  borderRadius: BorderRadius.circular(8.0),
                ),
                child: MacosListTile(
                  leading: MacosIcon(
                    CupertinoIcons.gear,
                    color: theme.brightness == Brightness.dark ? Colors.white : Colors.black,
                  ),
                  title: Text(
                    'Settings',
                    style: theme.typography.body,
                  ),
                  onClick: () {
                    setState(() => _pageIndex = 1);
                  },
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: PushButton(
                controlSize: ControlSize.regular,
                onPressed: () {
                  _showAddCategoryDialog(context);
                },
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    MacosIcon(
                      CupertinoIcons.add,
                      color: theme.brightness == Brightness.dark ? Colors.white : Colors.black,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Create Category',
                      style: theme.typography.body,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        bottom: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Show validation progress if available
            if (appState.validationProgress != null) _buildValidationProgress(context, appState.validationProgress!),

            MacosListTile(
              leading: MacosIcon(
                CupertinoIcons.app_badge,
                color: theme.brightness == Brightness.dark ? Colors.white : Colors.black,
              ),
              title: Text(
                'Later',
                style: theme.typography.body,
              ),
              subtitle: Text(
                'Version ${appState.appVersion}',
                style: theme.typography.caption2,
              ),
            ),
          ],
        ),
      ),
      child: IndexedStack(
        index: _pageIndex,
        children: [
          HomePage(
            onSettingsPressed: () {
              setState(() => _pageIndex = 1);
            },
          ),
          const SettingsPage(),
        ],
      ),
    );
  }

  void _showAddCategoryDialog(BuildContext context) {
    final TextEditingController controller = TextEditingController();
    final theme = MacosTheme.of(context);

    showMacosAlertDialog(
      context: context,
      builder: (_) => MacosAlertDialog(
        appIcon: MacosIcon(
          CupertinoIcons.folder_badge_plus,
          size: 56,
          color: theme.primaryColor,
        ),
        title: const Text('Create New Category'),
        message: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16.0),
          child: MacosTextField(
            placeholder: 'Category Name',
            controller: controller,
          ),
        ),
        primaryButton: PushButton(
          controlSize: ControlSize.large,
          onPressed: () {
            if (controller.text.trim().isNotEmpty) {
              final newCategory = Category(name: controller.text.trim());
              ref.read(appNotifier.notifier).addCategory(newCategory);
              Navigator.of(context).pop();
            }
          },
          child: const Text('Create'),
        ),
        secondaryButton: PushButton(
          controlSize: ControlSize.large,
          secondary: true,
          onPressed: () {
            Navigator.of(context).pop();
          },
          child: const Text('Cancel'),
        ),
      ),
    );
  }

  void _showEditCategoryDialog(BuildContext context, Category category) {
    final TextEditingController controller = TextEditingController(text: category.name);
    final theme = MacosTheme.of(context);

    showMacosAlertDialog(
      context: context,
      builder: (_) => MacosAlertDialog(
        appIcon: MacosIcon(
          CupertinoIcons.folder,
          size: 56,
          color: theme.primaryColor,
        ),
        title: const Text('Edit Category'),
        message: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16.0),
          child: MacosTextField(
            placeholder: 'Category Name',
            controller: controller,
          ),
        ),
        primaryButton: PushButton(
          controlSize: ControlSize.large,
          onPressed: () {
            final newName = controller.text.trim();
            if (newName.isNotEmpty) {
              // Only update if the name has changed
              if (newName != category.name) {
                final updatedCategory = category.copyWith(name: newName);
                ref.read(appNotifier.notifier).updateCategory(updatedCategory);
              }
              Navigator.of(context).pop();
            }
          },
          child: const Text('Save'),
        ),
        secondaryButton: PushButton(
          controlSize: ControlSize.large,
          secondary: true,
          onPressed: () {
            Navigator.of(context).pop();
          },
          child: const Text('Cancel'),
        ),
      ),
    );
  }

  // Show context menu for a category
  void _showCategoryContextMenu(BuildContext context, Category category, Offset position) {
    final theme = MacosTheme.of(context);
    final appNotifierRef = ref.read(appNotifier.notifier);

    showMenu(
      context: context,
      position: RelativeRect.fromLTRB(
        position.dx,
        position.dy,
        position.dx + 1,
        position.dy + 1,
      ),
      items: [
        PopupMenuItem(
          child: Row(
            children: [
              MacosIcon(
                CupertinoIcons.link_badge_plus,
                color: theme.brightness == Brightness.dark ? Colors.white : Colors.black,
                size: 18,
              ),
              const SizedBox(width: 8),
              const Text('Add URL to category'),
            ],
          ),
          onTap: () {
            // Use Future.delayed to avoid "Looking up a deactivated widget's ancestor" error
            Future.delayed(Duration.zero, () {
              _showAddUrlToCategoryDialog(context, category);
            });
          },
        ),
        PopupMenuItem(
          child: Row(
            children: [
              MacosIcon(
                CupertinoIcons.pencil,
                color: theme.brightness == Brightness.dark ? Colors.white : Colors.black,
                size: 18,
              ),
              const SizedBox(width: 8),
              const Text('Edit category'),
            ],
          ),
          onTap: () {
            Future.delayed(Duration.zero, () {
              _showEditCategoryDialog(context, category);
            });
          },
        ),
        PopupMenuItem(
          child: Row(
            children: [
              MacosIcon(
                CupertinoIcons.photo,
                color: theme.brightness == Brightness.dark ? Colors.white : Colors.black,
                size: 18,
              ),
              const SizedBox(width: 8),
              const Text('Change icon'),
            ],
          ),
          onTap: () {
            Future.delayed(Duration.zero, () {
              _showChangeCategoryIconDialog(context, category);
            });
          },
        ),
        PopupMenuItem(
          child: Row(
            children: [
              MacosIcon(
                CupertinoIcons.arrow_up_doc,
                color: theme.brightness == Brightness.dark ? Colors.white : Colors.black,
                size: 18,
              ),
              const SizedBox(width: 8),
              const Text('Export category'),
            ],
          ),
          onTap: () {
            Future.delayed(Duration.zero, () {
              _exportCategory(context, category);
            });
          },
        ),
        PopupMenuItem(
          child: Row(
            children: [
              MacosIcon(
                CupertinoIcons.trash,
                color: MacosColors.systemRedColor,
                size: 18,
              ),
              const SizedBox(width: 8),
              Text(
                'Delete category',
                style: TextStyle(
                  color: MacosColors.systemRedColor,
                ),
              ),
            ],
          ),
          onTap: () {
            Future.delayed(Duration.zero, () {
              _showDeleteCategoryConfirmation(context, category);
            });
          },
        ),
      ],
    );
  }

  // Show dialog to add a URL to a category
  void _showAddUrlToCategoryDialog(BuildContext context, Category category) {
    final TextEditingController controller = TextEditingController();
    final TextEditingController titleController = TextEditingController();
    final theme = MacosTheme.of(context);

    showMacosAlertDialog(
      context: context,
      builder: (_) => MacosAlertDialog(
        appIcon: MacosIcon(
          CupertinoIcons.link_badge_plus,
          size: 56,
          color: theme.primaryColor,
        ),
        title: Text('Add URL to ${category.name}'),
        message: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              MacosTextField(
                placeholder: 'URL (e.g., https://example.com)',
                controller: controller,
              ),
              const SizedBox(height: 12),
              MacosTextField(
                placeholder: 'Title (optional)',
                controller: titleController,
              ),
            ],
          ),
        ),
        primaryButton: PushButton(
          controlSize: ControlSize.large,
          onPressed: () {
            final url = controller.text.trim();
            if (url.isNotEmpty) {
              // Create a new URL item
              final newUrl = UrlItem(
                url: url,
                title: titleController.text.trim().isNotEmpty ? titleController.text.trim() : url,
                categoryId: category.id,
              );

              // Add the URL to the app
              ref.read(appNotifier.notifier).addUrl(newUrl, fetchMetadata: true);
              Navigator.of(context).pop();
            }
          },
          child: const Text('Add'),
        ),
        secondaryButton: PushButton(
          controlSize: ControlSize.large,
          secondary: true,
          onPressed: () {
            Navigator.of(context).pop();
          },
          child: const Text('Cancel'),
        ),
      ),
    );
  }

  // Show dialog to change a category's icon
  void _showChangeCategoryIconDialog(BuildContext context, Category category) {
    final theme = MacosTheme.of(context);
    final appNotifierRef = ref.read(appNotifier.notifier);

    // List of available icons
    final iconOptions = [
      {'name': 'folder', 'icon': CupertinoIcons.folder},
      {'name': 'bookmark', 'icon': CupertinoIcons.bookmark},
      {'name': 'link', 'icon': CupertinoIcons.link},
      {'name': 'doc', 'icon': CupertinoIcons.doc},
      {'name': 'book', 'icon': CupertinoIcons.book},
      {'name': 'tag', 'icon': CupertinoIcons.tag},
      {'name': 'star', 'icon': CupertinoIcons.star},
      {'name': 'heart', 'icon': CupertinoIcons.heart},
      {'name': 'globe', 'icon': CupertinoIcons.globe},
      {'name': 'person', 'icon': CupertinoIcons.person},
      {'name': 'cart', 'icon': CupertinoIcons.cart},
      {'name': 'gift', 'icon': CupertinoIcons.gift},
      {'name': 'calendar', 'icon': CupertinoIcons.calendar},
      {'name': 'clock', 'icon': CupertinoIcons.clock},
      {'name': 'music_note', 'icon': CupertinoIcons.music_note},
      {'name': 'photo', 'icon': CupertinoIcons.photo},
      {'name': 'video', 'icon': CupertinoIcons.video_camera},
      {'name': 'game', 'icon': CupertinoIcons.game_controller},
      {'name': 'mail', 'icon': CupertinoIcons.mail},
      {'name': 'chat', 'icon': CupertinoIcons.chat_bubble},
    ];

    showMacosAlertDialog(
      context: context,
      builder: (_) => MacosAlertDialog(
        appIcon: MacosIcon(
          CupertinoIcons.photo,
          size: 56,
          color: theme.primaryColor,
        ),
        title: Text('Change Icon for ${category.name}'),
        message: SizedBox(
          width: 400,
          height: 300,
          child: GridView.builder(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 5,
              childAspectRatio: 1,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
            ),
            itemCount: iconOptions.length,
            itemBuilder: (context, index) {
              final iconOption = iconOptions[index];
              final isSelected = category.iconName == iconOption['name'];

              return GestureDetector(
                onTap: () {
                  // Update the category with the new icon
                  final updatedCategory = category.copyWith(iconName: iconOption['name'] as String);
                  appNotifierRef.updateCategory(updatedCategory);
                  Navigator.of(context).pop();
                },
                child: Container(
                  decoration: BoxDecoration(
                    color: isSelected ? theme.primaryColor.withOpacity(0.2) : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isSelected ? theme.primaryColor : Colors.transparent,
                      width: 2,
                    ),
                  ),
                  child: Center(
                    child: MacosIcon(
                      iconOption['icon'] as IconData,
                      size: 24,
                      color: theme.brightness == Brightness.dark ? Colors.white : Colors.black,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        primaryButton: PushButton(
          controlSize: ControlSize.large,
          secondary: true,
          onPressed: () {
            Navigator.of(context).pop();
          },
          child: const Text('Cancel'),
        ),
      ),
    );
  }

  // Export only a specific category
  void _exportCategory(BuildContext context, Category category) async {
    final appState = ref.read(appNotifier);

    // Get URLs for this category
    final categoryUrls = appState.urls.where((url) => url.categoryId == category.id).toList();

    // Create export data with only this category
    final exportData = ExportData(
      categories: [category],
      urls: categoryUrls,
      version: appState.appVersion,
    );

    // Show export dialog
    final exportConfig = await showExportDialog(context);
    if (exportConfig != null) {
      // Import the import_export_manager
      final importExportManager = ImportExportManager();

      // Export the category
      await importExportManager.exportBookmarks(context, exportData, exportConfig);
    }
  }

  // Show confirmation dialog for deleting a category
  void _showDeleteCategoryConfirmation(BuildContext context, Category category) {
    final theme = MacosTheme.of(context);
    final appNotifierRef = ref.read(appNotifier.notifier);

    showMacosAlertDialog(
      context: context,
      builder: (_) => MacosAlertDialog(
        appIcon: MacosIcon(
          CupertinoIcons.exclamationmark_triangle,
          size: 56,
          color: MacosColors.systemRedColor,
        ),
        title: Text('Delete ${category.name}?'),
        message: Text(
          'This will permanently delete the category and all URLs in it. This action cannot be undone.',
          style: theme.typography.body,
        ),
        primaryButton: PushButton(
          controlSize: ControlSize.large,
          onPressed: () {
            // Delete the category
            appNotifierRef.deleteCategory(category.id);
            Navigator.of(context).pop();
          },
          color: MacosColors.systemRedColor,
          child: const Text('Delete'),
        ),
        secondaryButton: PushButton(
          controlSize: ControlSize.large,
          secondary: true,
          onPressed: () {
            Navigator.of(context).pop();
          },
          child: const Text('Cancel'),
        ),
      ),
    );
  }

  // Build the validation progress UI for the sidebar
  Widget _buildValidationProgress(BuildContext context, ValidationProgress progress) {
    final theme = MacosTheme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: theme.canvasColor,
        border: Border(
          top: BorderSide(
            color: theme.dividerColor,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const MacosIcon(
                CupertinoIcons.arrow_clockwise,
                size: 16,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Validating URLs...',
                  style: theme.typography.caption1,
                ),
              ),
              Text(
                '${progress.completed}/${progress.total}',
                style: theme.typography.caption1,
              ),
            ],
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress.percentage / 100,
              backgroundColor: theme.brightness == Brightness.dark ? MacosColors.systemGrayColor.withOpacity(0.3) : MacosColors.systemGrayColor.withOpacity(0.1),
              valueColor: AlwaysStoppedAnimation<Color>(theme.primaryColor),
              minHeight: 4,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            progress.currentUrl,
            style: theme.typography.caption2.copyWith(
              color: theme.primaryColor,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
