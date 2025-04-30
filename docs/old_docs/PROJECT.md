# Later - URL Bookmarking System

## Project Overview

Later is a comprehensive URL bookmarking system designed to help users save, organize, and manage web links across different browsers and devices. The project consists of a macOS desktop application and browser extensions for Chrome and Firefox, providing a seamless experience for collecting and organizing web content.

## Vision & Goals

The vision for Later is to create a streamlined, user-friendly system that allows users to:

1. Quickly save web pages for later viewing
2. Organize saved URLs into customizable categories
3. Easily search and filter through saved content
4. Seamlessly transfer tabs between browsers and the desktop application
5. Maintain a clean, native macOS experience with modern UI patterns

## Project Structure

The Later project is organized into three main components:

### 1. macOS Desktop Application

Built with Flutter and the macos_ui package, the desktop application provides a native macOS experience with a sidebar-based interface.

**Key Files and Directories:**
- `macos_app/lib/models/` - Data models for categories, URLs, settings, and export data
- `macos_app/lib/providers/` - State management using Riverpod
- `macos_app/lib/pages/` - UI components for the main view, home page, and settings
- `macos_app/lib/utils/` - Utility classes including system tray management

### 2. Chrome Extension

A browser extension for Chrome that allows users to save tabs to the Later app.

**Key Files:**
- `chrome_extension/manifest.json` - Extension configuration
- `chrome_extension/popup.html` and `popup.js` - UI and functionality for the popup
- `chrome_extension/background.js` - Background script for handling keyboard shortcuts

### 3. Firefox Extension

A browser extension for Firefox with functionality similar to the Chrome extension but adapted for Firefox's WebExtensions API.

**Key Files:**

- `firefox_extension/manifest.json` - Extension configuration
- `firefox_extension/popup.html` and `popup.js` - UI and functionality for the popup
- `firefox_extension/background.js` - Background script for handling keyboard shortcuts

## Current Implementation Status

### Completed Components

1. **Data Models**
   - Category model
   - URL model
   - Settings model
   - Export/Import data model

2. **State Management**
   - Riverpod providers for app state and settings
   - Preferences repository for data persistence

3. **Basic UI Structure**
   - Main view with sidebar and content area
   - Settings page with theme and system tray options
   - URL card component for displaying saved URLs

4. **Browser Extensions**
   - Basic structure for Chrome and Firefox extensions
   - Functionality to export tabs as JSON to clipboard
   - Category management within extensions

### Remaining Tasks

According to the project roadmap (TODO.md), the following tasks are still in progress:

1. **macOS Application UI**
   - Implement search functionality in sidebar and main content
   - Complete "Add URL" functionality
   - Implement export and import list functionality
   - Enhance system tray functionality

2. **Data Management**
   - Optimize data loading and saving
   - Implement proper error handling
   - Add support for large numbers of categories and URLs

3. **Browser Extensions**
   - Complete integration with the macOS app
   - Add icons and finalize UI
   - Test across different browser versions

4. **Testing and Polishing**
   - Comprehensive testing of all features
   - UI refinement and consistency
   - Performance optimization

## Technical Implementation

### macOS Application

The macOS application is built using Flutter with the following key technologies:

1. **Framework**: Flutter for macOS
2. **UI Package**: macos_ui for native macOS components
3. **State Management**: Riverpod (a variation of the BLoC pattern)
4. **Data Persistence**: SharedPreferences for storing app data
5. **System Integration**: system_tray package for system tray functionality

The application follows an immutable data pattern with clear separation of concerns:
- Models define the data structure
- Providers manage state and business logic
- UI components display data and handle user interactions

### Browser Extensions

Both browser extensions are built using standard web technologies:

1. **Chrome Extension**: Uses Manifest V3 with service workers
2. **Firefox Extension**: Uses WebExtensions API (Manifest V2)

The extensions share a common approach:
- Store categories in browser storage
- Access tab information using browser APIs
- Format data as JSON and copy to clipboard
- Provide keyboard shortcuts for quick access

## Data Flow

1. **Saving URLs**:
   - User saves tabs from browser extensions
   - Data is formatted as JSON and copied to clipboard
   - User imports data into the macOS app from clipboard

2. **Managing URLs**:
   - URLs are organized into categories in the macOS app
   - User can search, edit, and delete URLs
   - Changes are persisted to local storage

3. **Settings Management**:
   - User preferences are stored and retrieved from local storage
   - Settings affect app behavior (theme, system tray, etc.)

## Possible Enhancements

Based on the current implementation, the following enhancements could be considered:

1. **Cross-Platform Support**
   - Extend the desktop application to Windows and Linux
   - Create mobile applications for iOS and Android

2. **Cloud Synchronization**
   - Add support for syncing data across devices
   - Implement user accounts and authentication

3. **Advanced URL Management**
   - Add tags for more flexible organization
   - Implement automatic categorization based on URL content
   - Add support for reading lists and favorites

4. **Browser Integration**
   - Develop deeper integration with browsers
   - Add support for more browsers (Safari, Edge, etc.)
   - Implement direct communication between extensions and app

5. **Content Features**
   - Add support for saving page content (not just URLs)
   - Implement reading mode for saved articles
   - Add annotation and highlighting features

6. **Performance Optimizations**
   - Implement pagination for large collections
   - Add database support for better performance with large datasets
   - Optimize memory usage for the desktop application

## Conclusion

Later is a well-structured project with a clear vision and roadmap. The current implementation provides a solid foundation for a URL bookmarking system with a native macOS experience and browser integration. With continued development according to the roadmap and potential enhancements, Later has the potential to become a comprehensive solution for web content management.