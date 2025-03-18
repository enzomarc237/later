# Later App Implementation Roadmap

## 1. Data Models and State Management

### 1.1 Data Models

- [x] Create Category model
- [x] Create URL model
- [x] Create Settings model
- [x] Create ExportData model for import/export functionality

### 1.2 State Management

- [x] Update AppState to include categories and selected category
- [x] Update SettingsState to include theme and data folder settings
- [x] Create CategoryNotifier for managing categories (implemented in AppNotifier)
- [x] Create URLNotifier for managing URLs (implemented in AppNotifier)
- [x] Update PreferencesRepository to store and retrieve categories and URLs

## 2. MacOS Application UI

### 2.1 Main Interface

- [x] Update MainView to display categories in sidebar
- [x] Implement search functionality in sidebar
- [x] Create "Create Category" button at bottom of sidebar
- [x] Implement URL list view in main content area
- [x] Implement search functionality for URLs
- [x] Create URL detail view/card component
- [x] Add "All URLs" button to view URLs across all categories
- [x] Refine sidebar spacing and navigation

### 2.2 Toolbar

- [x] Implement "Add URL" button and functionality
- [x] Implement "Export List" button and functionality
- [x] Implement "Import List" button and functionality
- [x] Implement "Go to Settings" button

### 2.3 Settings Page

- [x] Implement theme selection (Light/Dark)
- [x] Implement data folder selection
- [x] Implement "Clear All Data" functionality
- [x] Implement browser extensions setup instructions

### 2.4 System Tray

- [x] Implement system tray icon
- [x] Create context menu with options:
  - [x] Open App Main View
  - [x] Import Tabs from Clipboard
  - [x] Close App
- [x] Implement functionality for each option
- [x] Prevent app exit on window close (hide to system tray instead)

## 3. Browser Extensions

### 3.1 Chrome Extension

- [x] Create manifest.json file (Manifest V3)
- [x] Implement popup UI
- [x] Implement functionality to export:
  - [x] Currently opened tab
  - [x] All tabs in current window
  - [x] All tabs across all windows
- [x] Implement clipboard export functionality
- [x] Add direct URL scheme communication with macOS app

### 3.2 Firefox Extension

- [x] Create manifest.json file (WebExtensions API)
- [x] Implement popup UI
- [x] Implement functionality to export:
  - [x] Currently opened tab
  - [x] All tabs in current window
  - [x] All tabs across all windows
- [x] Implement clipboard export functionality
- [x] Add direct URL scheme communication with macOS app

## 4. Integration and Testing

### 4.1 Integration

- [x] Ensure the macOS app can import URLs from clipboard
- [x] Test the workflow from exporting tabs to importing them
- [x] Implement custom URL scheme for direct communication between extensions and app

### 4.2 Testing

- [x] Test category management
- [x] Test URL management
- [x] Test settings functionality
- [x] Test system tray functionality
- [x] Test browser extensions

## 5. Polishing

### 5.1 UI Refinement

- [x] Ensure consistent styling across the app
- [x] Implement proper error handling and user feedback
- [x] Add animations and transitions for better UX
- [x] Add notifications for user actions

### 5.2 Performance Optimization

- [x] Optimize data loading and saving
- [x] Ensure smooth performance with large numbers of categories and URLs

## 6. Recent Enhancements

### 6.1 UI Improvements

- [x] Refined sidebar with better spacing and visual hierarchy
- [x] Added "All URLs" button at the top of the sidebar
- [x] Improved category selection and navigation

### 6.2 System Integration

- [x] Added window management to keep app running in background
- [x] Implemented notifications for user actions
- [x] Added custom URL scheme for direct communication with browser extensions

## 7. Future Enhancements

### 7.1 Data Storage Improvements

- [x] Implement file-based storage using the data folder path setting
- [x] Add migration from SharedPreferences to file-based storage
- [x] Add automatic backups of user data
- [ ] Implement data import/export in various formats (JSON, HTML, CSV)
- [ ] Add cloud sync capabilities (iCloud, Dropbox, etc.)

### 7.2 URL Management Enhancements

- [ ] Add advanced search and filtering capabilities
- [x] Implement bulk operations (select multiple URLs to delete or move)
- [ ] Add drag-and-drop for organizing URLs between categories
- [ ] Implement auto-categorization based on URL patterns or content
- [ ] Add URL validation to check for dead links
- [ ] Auto-fetch favicons and metadata from websites
- [ ] Add preview thumbnails for URLs

### 7.3 Organization Features

- [ ] Implement a tagging system in addition to categories
- [ ] Add tag suggestions based on URL content
- [ ] Create smart collections based on rules (domains, keywords, etc.)
- [ ] Add favorites/starred items functionality
- [ ] Implement a "recently added" or "recently viewed" section

### 7.4 UI Improvements

- [ ] Add customizable themes beyond just light/dark
- [x] Implement keyboard shortcuts for power users
- [ ] Add list and grid view options for URLs
- [ ] Make sidebar width adjustable
- [ ] Add more sorting options for URLs (alphabetical, date added, most used)
- [ ] Implement a reading mode for article URLs

### 7.5 Browser Integration Enhancements

- [ ] Improve browser extensions with more features
- [ ] Add right-click context menu integration
- [ ] Implement browser bookmark sync
- [ ] Add web clipper functionality to save article content
- [ ] Create a browser sidebar extension for quick access

### 7.6 Analytics and Insights

- [ ] Add usage statistics (most visited links, categories with most items)
- [ ] Implement visualizations of bookmark collection
- [ ] Add time-based analytics (saving patterns, usage patterns)
- [ ] Create reports on bookmark organization and suggestions
