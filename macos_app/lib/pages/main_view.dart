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

    return MacosWindow(
      sidebar: Sidebar(
        decoration: BoxDecoration(
          color: MacosTheme.of(context).canvasColor,
        ),
        minWidth: 200,
        builder: (context, scrollController) => Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(12.0), // Increased padding
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
            // All URLs button at the top - Simplified to ensure it's clickable
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
              child: PushButton(
                controlSize: ControlSize.large,
                secondary: true,
                color: appState.selectedCategoryId == null ? MacosColors.controlAccentColor : null,
                onPressed: () {
                  ref.read(appNotifier.notifier).selectCategory(null);
                  // Switch to HomePage
                  setState(() => _pageIndex = 0);
                },
                child: Row(
                  children: [
                    MacosIcon(
                      CupertinoIcons.doc_text_search,
                      color: appState.selectedCategoryId == null ? MacosColors.controlAccentColor : MacosColors.systemGrayColor,
                      size: 22.0,
                    ),
                    const SizedBox(width: 8.0),
                    Text(
                      'All URLs',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: appState.selectedCategoryId == null ? MacosColors.controlAccentColor : MacosColors.systemGrayColor,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8.0), // Extra spacing
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.0),
              child: Text(
                'Categories',
                style: TextStyle(
                  fontSize: 12.0,
                  fontWeight: FontWeight.bold,
                  color: MacosColors.systemGrayColor,
                ),
              ),
            ),
            const SizedBox(height: 8.0), // Extra spacing
            Expanded(
              child: appState.categories.isEmpty
                  ? const Center(
                      child: Text('No categories yet'),
                    )
                  : ListView.builder(
                      controller: scrollController,
                      itemCount: filteredCategories.length,
                      itemBuilder: (context, index) {
                        final category = filteredCategories[index];
                        final isSelected = category.id == appState.selectedCategoryId;
                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 2.0), // Added padding
                          child: Container(
                            decoration: BoxDecoration(
                              color: isSelected ? MacosColors.controlAccentColor.withOpacity(0.2) : Colors.transparent,
                              borderRadius: BorderRadius.circular(8.0), // Rounded corners
                            ),
                            child: MacosListTile(
                              // MacosListTile doesn't have contentPadding parameter
                              leading: const MacosIcon(CupertinoIcons.folder),
                              title: Text(category.name),
                              onClick: () {
                                ref.read(appNotifier.notifier).selectCategory(category.id);
                                // Switch to HomePage when a category is selected
                                setState(() => _pageIndex = 0);
                              },
                            ),
                          ),
                        );
                      },
                    ),
            ),
            const Divider(
              height: 24.0, // Increased height
              thickness: 1.0,
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 2.0), // Added padding
              child: Container(
                decoration: BoxDecoration(
                  color: _pageIndex == 1 ? MacosColors.controlAccentColor.withOpacity(0.2) : Colors.transparent,
                  borderRadius: BorderRadius.circular(8.0), // Rounded corners
                ),
                child: MacosListTile(
                  // MacosListTile doesn't have contentPadding parameter
                  leading: const MacosIcon(CupertinoIcons.gear),
                  title: const Text('Settings'),
                  onClick: () {
                    setState(() => _pageIndex = 1);
                  },
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12.0), // Increased padding
              child: PushButton(
                controlSize: ControlSize.regular,
                onPressed: () {
                  _showAddCategoryDialog(context);
                },
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    MacosIcon(CupertinoIcons.add),
                    SizedBox(width: 8), // Increased spacing
                    Text('Create Category'),
                  ],
                ),
              ),
            ),
          ],
        ),
        bottom: MacosListTile(
          leading: const MacosIcon(CupertinoIcons.app_badge),
          title: const Text('Later'),
          subtitle: Text('Version ${appState.appVersion}'),
        ),
      ),
      child: IndexedStack(
        index: _pageIndex,
        children: const [
          HomePage(),
          SettingsPage(),
        ],
      ),
    );
  }

  void _showAddCategoryDialog(BuildContext context) {
    final TextEditingController controller = TextEditingController();
    showMacosAlertDialog(
      context: context,
      builder: (_) => MacosAlertDialog(
        appIcon: const FlutterLogo(size: 56),
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
}
