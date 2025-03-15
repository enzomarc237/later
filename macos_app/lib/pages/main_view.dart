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
              padding: const EdgeInsets.all(8.0),
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
                        return MacosListTile(
                          leading: const MacosIcon(CupertinoIcons.folder),
                          title: Text(category.name),
                          onClick: () {
                            ref.read(appNotifier.notifier).selectCategory(category.id);
                          },
                          backgroundColor: isSelected ? MacosTheme.of(context).selection : Colors.transparent,
                        );
                      },
                    ),
            ),
            const Divider(),
            MacosListTile(
              leading: const MacosIcon(CupertinoIcons.gear),
              title: const Text('Settings'),
              onClick: () {
                setState(() => _pageIndex = 1);
              },
              backgroundColor: _pageIndex == 1 ? MacosTheme.of(context).selection : Colors.transparent,
            ),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: PushButton(
                controlSize: ControlSize.regular,
                onPressed: () {
                  _showAddCategoryDialog(context);
                },
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    MacosIcon(CupertinoIcons.add),
                    SizedBox(width: 4),
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
