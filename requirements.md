### Project Overview

**Objective:**
Develop a macOS application for bookmarking URLs with a sidebar for categories and a main view for displaying URLs. The application should include features for adding, exporting, and importing URLs, as well as settings management. Additionally, create browser extensions for Chrome and Firefox to facilitate URL export to the application.

### Application Features

1. **Main Interface:**
   - **Sidebar:** Displays a list of categories/folders.
   - **Main View:** Shows URLs associated with the selected category.
   - **Search Bars:** In both the sidebar and main view for filtering categories and URLs.
   - **Create Category Button:** Located at the bottom of the sidebar.

2. **Toolbar:**
   - **Buttons:**
     - Add URL
     - Export List
     - Import List
     - Go to Settings

3. **Settings Page:**
   - **Options:**
     - Theme selection (Light/Dark)
     - Data folder selection
     - Clear All Data
     - Browser Extensions Setup

4. **System Tray:**
   - **Context Menu:**
     - Open App Main View
     - Import Tabs from Clipboard
     - Close App

### Browser Extensions (Chrome and Firefox)

- **Functionality:**
  - Export the following to the macOS application:
    - Currently opened tab
    - All tabs in the current window
    - All tabs across all windows
  - **Implementation Options:**
    - Export tabs as JSON to clipboard for importing into the app.
    - Directly send tabs to the app via a URL or other communication method.

### Technical Details

- **Design Pattern:** BLoC (Business Logic Component) for state management.
- **Framework:** Flutter for macOS application development.
- **Extensions:**
  - Chrome: Manifest V3
  - Firefox: WebExtensions API

### Tasks

1. **macOS Application:**
   - Set up the Flutter project structure.
   - Implement BLoC for managing categories, URLs, and settings.
   - Add the macos_ui package for macOS-specific components: the sidebar, main view, toolbar, and settings page.
   - Implement a native macOS look based on the documentation of the macos_ui package contained in the macos_ui_documentation.md file
   - Implement system tray functionality.

2. **Browser Extensions:**
   - Create manifest files and necessary scripts for Chrome and Firefox.
   - Implement functionality to export tabs to JSON and copy to clipboard.

3. **Integration:**
   - Ensure the macOS application can import URLs from the clipboard.
   - Test the entire workflow from exporting tabs in the browser to importing them into the application.

By following this structured approach, you can develop a comprehensive URL bookmarking application with accompanying browser extensions, meeting all specified requirements.