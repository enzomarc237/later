# Later App Implementation Roadmap

## 1. Data Models and State Management

### 1.1 Data Models
- [ ] Create Category model
- [ ] Create URL model
- [ ] Create Settings model

### 1.2 State Management
- [ ] Update AppState to include categories and selected category
- [ ] Update SettingsState to include theme and data folder settings
- [ ] Create CategoryNotifier for managing categories
- [ ] Create URLNotifier for managing URLs
- [ ] Update PreferencesRepository to store and retrieve categories and URLs

## 2. MacOS Application UI

### 2.1 Main Interface
- [ ] Update MainView to display categories in sidebar
- [ ] Implement search functionality in sidebar
- [ ] Create "Create Category" button at bottom of sidebar
- [ ] Implement URL list view in main content area
- [ ] Implement search functionality for URLs
- [ ] Create URL detail view/card component

### 2.2 Toolbar
- [ ] Implement "Add URL" button and functionality
- [ ] Implement "Export List" button and functionality
- [ ] Implement "Import List" button and functionality
- [ ] Implement "Go to Settings" button

### 2.3 Settings Page
- [ ] Implement theme selection (Light/Dark)
- [ ] Implement data folder selection
- [ ] Implement "Clear All Data" functionality
- [ ] Implement browser extensions setup instructions

### 2.4 System Tray
- [ ] Implement system tray icon
- [ ] Create context menu with options:
  - [ ] Open App Main View
  - [ ] Import Tabs from Clipboard
  - [ ] Close App
- [ ] Implement functionality for each option

## 3. Browser Extensions

### 3.1 Chrome Extension
- [ ] Create manifest.json file (Manifest V3)
- [ ] Implement popup UI
- [ ] Implement functionality to export:
  - [ ] Currently opened tab
  - [ ] All tabs in current window
  - [ ] All tabs across all windows
- [ ] Implement clipboard export functionality

### 3.2 Firefox Extension
- [ ] Create manifest.json file (WebExtensions API)
- [ ] Implement popup UI
- [ ] Implement functionality to export:
  - [ ] Currently opened tab
  - [ ] All tabs in current window
  - [ ] All tabs across all windows
- [ ] Implement clipboard export functionality

## 4. Integration and Testing

### 4.1 Integration
- [ ] Ensure the macOS app can import URLs from clipboard
- [ ] Test the workflow from exporting tabs to importing them

### 4.2 Testing
- [ ] Test category management
- [ ] Test URL management
- [ ] Test settings functionality
- [ ] Test system tray functionality
- [ ] Test browser extensions

## 5. Polishing

### 5.1 UI Refinement
- [ ] Ensure consistent styling across the app
- [ ] Implement proper error handling and user feedback
- [ ] Add animations and transitions for better UX

### 5.2 Performance Optimization
- [ ] Optimize data loading and saving
- [ ] Ensure smooth performance with large numbers of categories and URLs