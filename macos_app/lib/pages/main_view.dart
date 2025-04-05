import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:macos_ui/macos_ui.dart';

import '../models/models.dart';
import '../providers/providers.dart';
import '../utils/import_export_manager.dart';
import 'export_dialog.dart';
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

  List<Category> _filterCategories(AppState appState) {
    return appState.categories
        .where((category) =>
            _searchQuery.isEmpty ||
            category.name.toLowerCase().contains(_searchQuery.toLowerCase()))
        .toList();
  }

  Sidebar _buildSidebar(MacosThemeData theme, AppState appState,
      List<Category> filteredCategories) {
    return Sidebar(
      decoration: BoxDecoration(
        color: theme.canvasColor,
      ),
      minWidth: 200,
      top: _buildTopSidebar(theme, appState),
      builder: (context, scrollController) => Column(
        children: [
          _buildSearchField(),
          const SizedBox(height: 8.0),
          _buildCategoryLabel(theme),
          const SizedBox(height: 8.0),
          _buildCategoryList(appState, filteredCategories, scrollController),
          _buildSettingsOption(theme, 1),
          _buildBottomSidebar(appState, theme),
        ],
      ),
    );
  }

  Padding _buildCategoryLabel(MacosThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Text(
        'Categories',
        style: theme.typography.subheadline.copyWith(
          fontWeight: FontWeight.bold,
          color: theme.brightness == Brightness.dark
              ? MacosColors.systemGrayColor
              : MacosColors.systemGrayColor,
        ),
      ),
    );
  }

  Padding _buildSearchField() {
    return Padding(
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
    );
  }

  Padding _buildTopSidebar(MacosThemeData theme, AppState appState) {
    return Padding(
      padding: const EdgeInsets.all(12.0),
      child: PushButton(
        controlSize: ControlSize.large,
        secondary: true,
        color: appState.selectedCategoryId == null ? theme.primaryColor : null,
        onPressed: () => _clearSelectedCategory(appState),
        child: _buildTopButtonContent(theme, appState),
      ),
    );
  }

  void _clearSelectedCategory(AppState appState) {
    ref.read(appNotifier.notifier).clearSelectedCategory();
    setState(() {
      _pageIndex = 0;
    });
    debugPrint('All URLs button clicked, clearing filters');
  }

  Row _buildTopButtonContent(MacosThemeData theme, AppState appState) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        MacosIcon(
          CupertinoIcons.doc_text_search,
          color: appState.selectedCategoryId == null
              ? theme.primaryColor
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
                : MacosColors.systemGrayColor,
          ),
        ),
      ],
    );
  }

  Expanded _buildCategoryList(AppState appState,
      List<Category> filteredCategories, ScrollController scrollController) {
    return Expanded(
      child: appState.categories.isEmpty
          ? _buildEmptyCategoryLabel(appState)
          : ListView.builder(
              controller: scrollController,
              itemCount: filteredCategories.length,
              itemBuilder: (context, index) {
                final category = filteredCategories[index];
                final isSelected = category.id == appState.selectedCategoryId;
                return _buildCategoryItem(category, isSelected, appState);
              },
            ),
    );
  }

  Center _buildEmptyCategoryLabel(AppState appState) {
    final theme = MacosTheme.of(context);
    return Center(
      child: Text(
        'No categories yet',
        style: theme.typography.body,
      ),
    );
  }

  Padding _buildCategoryItem(
      Category category, bool isSelected, AppState appState) {
    final theme = MacosTheme.of(context);
    return Padding(
      // Increase vertical padding here
      padding: const EdgeInsets.symmetric(
          horizontal: 8.0, vertical: 6.0), // Increased vertical padding
      child: Container(
        decoration: BoxDecoration(
          color: isSelected
              ? theme.primaryColor.withOpacity(0.2)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8.0),
        ),
        child: GestureDetector(
          onSecondaryTapUp: (details) => _showCategoryContextMenu(
              context, category, details.globalPosition),
          child: Row(
            children: [
              Expanded(
                child: MacosListTile(
                  leading: Padding(
                    padding: const EdgeInsets.only(left: 8.0),
                    child: MacosIcon(
                      category.icon,
                      color: theme.brightness == Brightness.dark
                          ? Colors.white
                          : Colors.black,
                    ),
                  ),
                  title: Padding(
                    padding: const EdgeInsets.fromLTRB(2.0, 8.0, 2.0, 8.0),
                    child: Text(
                      category.name,
                      style: theme.typography.body,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  onClick: () {
                    ref.read(appNotifier.notifier).selectCategory(category.id);
                    setState(() => _pageIndex = 0);
                  },
                ),
              ),
              _buildCategoryOptionsButton(context, category, theme),
            ],
          ),
        ),
      ),
    );
  }

  MacosIconButton _buildCategoryOptionsButton(
      BuildContext context, Category category, MacosThemeData theme) {
    return MacosIconButton(
      icon: MacosIcon(
        CupertinoIcons.ellipsis,
        size: 16,
        color:
            theme.brightness == Brightness.dark ? Colors.white : Colors.black,
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
    );
  }

  Padding _buildSettingsOption(MacosThemeData theme, int pageIndex) {
    return Padding(
      // Increase vertical padding here
      padding: const EdgeInsets.symmetric(
          horizontal: 8.0, vertical: 8.0), // Increased vertical padding
      child: Container(
        decoration: BoxDecoration(
          color: _pageIndex == pageIndex
              ? theme.primaryColor.withOpacity(0.2)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8.0),
        ),
        child: MacosListTile(
          leading: MacosIcon(
            CupertinoIcons.gear,
            color: theme.brightness == Brightness.dark
                ? Colors.white
                : Colors.black,
          ),
          title: Text(
            'Settings',
            style: theme.typography.body,
          ),
          onClick: () {
            setState(() => _pageIndex = pageIndex);
          },
        ),
      ),
    );
  }

  Widget _buildBottomSidebar(AppState appState, MacosThemeData theme) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (appState.validationProgress != null)
          _buildValidationProgress(context, appState.validationProgress!),

        // Add Create Category as a SidebarItem
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 6.0),
          child: MacosListTile(
            leading: MacosIcon(
              CupertinoIcons.add,
              color: theme.brightness == Brightness.dark
                  ? Colors.white
                  : Colors.black,
            ),
            title: Text(
              'Create Category',
              style: theme.typography.body,
            ),
            onClick: () {
              _showAddCategoryDialog(context);
            },
          ),
        ),

        const SizedBox(height: 8), // Add spacing between items

        // Keep Version Info
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0),
          child: MacosListTile(
            leading: MacosIcon(
              CupertinoIcons.app_badge,
              color: theme.brightness == Brightness.dark
                  ? Colors.white
                  : Colors.black,
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
        ),

        const SizedBox(height: 16.0), // Add spacing between items
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final appState = ref.watch(appNotifier);
    final filteredCategories = _filterCategories(appState);
    final theme = MacosTheme.of(context);

    return MacosWindow(
      backgroundColor: Colors.transparent,
      sidebar: _buildSidebar(theme, appState, filteredCategories),
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
    final TextEditingController controller =
        TextEditingController(text: category.name);
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
  void _showCategoryContextMenu(
      BuildContext context, Category category, Offset position) {
    final theme = MacosTheme.of(context);
    // final appNotifierRef = ref.read(appNotifier.notifier); // Removed unused variable
    final isDark = theme.brightness == Brightness.dark;

    // Define styles based on theme
    final menuItemStyle = theme.typography.body;
    final shortcutStyle = theme.typography.caption2.copyWith(
      color: MacosColors.systemGrayColor.withOpacity(0.8),
    );
    final destructiveColor = MacosColors.systemRedColor;
    final iconColor = isDark ? MacosColors.white : MacosColors.black;

    showMenu<void>(
      context: context,
      position: RelativeRect.fromLTRB(
        position.dx,
        position.dy,
        position.dx + 1, // Required for position calculation
        position.dy + 1, // Required for position calculation
      ),
      // Style the menu background and shape using MacosTheme principles
      color: theme.brightness == Brightness.dark
          ? const Color(0xFF2C2C2C) // Dark mode menu background
          : const Color(0xFFF5F5F5), // Light mode menu background
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(6),
        side: BorderSide(
          color: theme.brightness == Brightness.dark
              ? MacosColors.systemGrayColor.withOpacity(0.3)
              : MacosColors.systemGrayColor.withOpacity(0.2),
          width: 0.5,
        ),
      ),
      elevation: 4, // Standard macOS menu elevation
      items: [
        // URLs Management Group
        PopupMenuItem<void>(
          height: 30, // Standard macOS menu item height
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: [
              MacosIcon(CupertinoIcons.link_circle, color: iconColor, size: 16),
              const SizedBox(width: 8),
              Expanded(
                  child: Text('Add URL to category', style: menuItemStyle)),
              Text('⌘N', style: shortcutStyle),
            ],
          ),
          // Use Future.delayed to avoid issues with Navigator during build
          onTap: () => Future.delayed(Duration.zero,
              () => _showAddUrlToCategoryDialog(context, category)),
        ),
        PopupMenuItem<void>(
          height: 30,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: [
              MacosIcon(CupertinoIcons.share, color: iconColor, size: 16),
              const SizedBox(width: 8),
              Expanded(child: Text('Share Category', style: menuItemStyle)),
              Text('⌘S', style: shortcutStyle),
            ],
          ),
          onTap: () {/* Implement sharing */},
        ),

        const PopupMenuDivider(height: 10), // Standard divider with padding

        // Category Customization Group
        PopupMenuItem<void>(
          height: 30,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: [
              MacosIcon(CupertinoIcons.pencil_circle,
                  color: iconColor, size: 16),
              const SizedBox(width: 8),
              Expanded(child: Text('Edit Category', style: menuItemStyle)),
              Text('⌘E', style: shortcutStyle),
            ],
          ),
          onTap: () => Future.delayed(
              Duration.zero, () => _showEditCategoryDialog(context, category)),
        ),
        PopupMenuItem<void>(
          height: 30,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: [
              MacosIcon(CupertinoIcons.photo_on_rectangle,
                  color: iconColor, size: 16),
              const SizedBox(width: 8),
              Expanded(child: Text('Change Icon', style: menuItemStyle)),
              Text('⌘I', style: shortcutStyle),
            ],
          ),
          onTap: () => Future.delayed(Duration.zero,
              () => _showChangeCategoryIconDialog(context, category)),
        ),

        const PopupMenuDivider(height: 10),

        // Import/Export Group
        PopupMenuItem<void>(
          height: 30,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: [
              MacosIcon(CupertinoIcons.arrow_down_doc,
                  color: iconColor, size: 16),
              const SizedBox(width: 8),
              Expanded(child: Text('Import to Category', style: menuItemStyle)),
              Text('⌥⌘I', style: shortcutStyle),
            ],
          ),
          onTap: () {/* Implement import */},
        ),
        PopupMenuItem<void>(
          height: 30,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: [
              MacosIcon(CupertinoIcons.arrow_up_doc,
                  color: iconColor, size: 16),
              const SizedBox(width: 8),
              Expanded(child: Text('Export Category', style: menuItemStyle)),
              Text('⌥⌘E', style: shortcutStyle),
            ],
          ),
          onTap: () => Future.delayed(
              Duration.zero, () => _exportCategory(context, category)),
        ),

        const PopupMenuDivider(height: 10),

        // Destructive Actions Group
        PopupMenuItem<void>(
          height: 30,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: [
              MacosIcon(CupertinoIcons.archivebox, color: iconColor, size: 16),
              const SizedBox(width: 8),
              Expanded(child: Text('Archive Category', style: menuItemStyle)),
              Text('⌘A', style: shortcutStyle),
            ],
          ),
          onTap: () {/* Implement archive */},
        ),
        PopupMenuItem<void>(
          height: 30,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: [
              MacosIcon(CupertinoIcons.trash,
                  color: destructiveColor, size: 16),
              const SizedBox(width: 8),
              Expanded(
                  child: Text('Delete Category',
                      style: menuItemStyle.copyWith(color: destructiveColor))),
              Text('⌘⌫',
                  style: shortcutStyle.copyWith(color: destructiveColor)),
            ],
          ),
          onTap: () => Future.delayed(Duration.zero,
              () => _showDeleteCategoryConfirmation(context, category)),
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
          CupertinoIcons.add_circled,
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
                title: titleController.text.trim().isNotEmpty
                    ? titleController.text.trim()
                    : url,
                categoryId: category.id,
              );

              // Add the URL to the app
              ref
                  .read(appNotifier.notifier)
                  .addUrl(newUrl, fetchMetadata: true);
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
                  final updatedCategory =
                      category.copyWith(iconName: iconOption['name'] as String);
                  appNotifierRef.updateCategory(updatedCategory);
                  Navigator.of(context).pop();
                },
                child: Container(
                  decoration: BoxDecoration(
                    color: isSelected
                        ? theme.primaryColor.withOpacity(0.2)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color:
                          isSelected ? theme.primaryColor : Colors.transparent,
                      width: 2,
                    ),
                  ),
                  child: Center(
                    child: MacosIcon(
                      iconOption['icon'] as IconData,
                      size: 24,
                      color: theme.brightness == Brightness.dark
                          ? Colors.white
                          : Colors.black,
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
    final categoryUrls =
        appState.urls.where((url) => url.categoryId == category.id).toList();

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
      await importExportManager.exportBookmarks(
          context, exportData, exportConfig);
    }
  }

  // Show confirmation dialog for deleting a category
  void _showDeleteCategoryConfirmation(
      BuildContext context, Category category) {
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
  Widget _buildValidationProgress(
      BuildContext context, ValidationProgress progress) {
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
              backgroundColor: theme.brightness == Brightness.dark
                  ? MacosColors.systemGrayColor.withOpacity(0.3)
                  : MacosColors.systemGrayColor.withOpacity(0.1),
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
