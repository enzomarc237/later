// Listen for keyboard shortcuts
browser.commands.onCommand.addListener(function(command) {
  if (command === 'save_all_tabs') {
    saveAllTabs();
  } else if (command === '_execute_browser_action') {
    saveCurrentTab();
  }
});

// Save current tab
function saveCurrentTab() {
  browser.storage.sync.get('categories').then(function(data) {
    const categories = data.categories || [];
    
    // If no categories exist, create a default one
    if (categories.length === 0) {
      const defaultCategory = {
        id: generateId(),
        name: 'Bookmarks'
      };
      categories.push(defaultCategory);
      return browser.storage.sync.set({ categories: categories }).then(function() {
        return categories;
      });
    }
    
    return categories;
  }).then(function(categories) {
    // Use the first category as default
    const categoryId = categories[0].id;
    
    return browser.tabs.query({ active: true, currentWindow: true }).then(function(tabs) {
      if (tabs.length === 0) {
        console.error('No active tab found');
        return;
      }
      
      const tab = tabs[0];
      return saveTabToClipboard([tab], categoryId);
    });
  }).catch(function(error) {
    console.error('Error in saveCurrentTab:', error);
  });
}

// Save all tabs
function saveAllTabs() {
  browser.storage.sync.get('categories').then(function(data) {
    const categories = data.categories || [];
    
    // If no categories exist, create a default one
    if (categories.length === 0) {
      const defaultCategory = {
        id: generateId(),
        name: 'Bookmarks'
      };
      categories.push(defaultCategory);
      return browser.storage.sync.set({ categories: categories }).then(function() {
        return categories;
      });
    }
    
    return categories;
  }).then(function(categories) {
    // Use the first category as default
    const categoryId = categories[0].id;
    
    return browser.tabs.query({ currentWindow: true }).then(function(tabs) {
      if (tabs.length === 0) {
        console.error('No tabs found');
        return;
      }
      
      return saveTabToClipboard(tabs, categoryId);
    });
  }).catch(function(error) {
    console.error('Error in saveAllTabs:', error);
  });
}

// Save tabs to clipboard
function saveTabToClipboard(tabs, categoryId) {
  const urlItems = tabs.map(tab => {
    return {
      id: generateId(),
      url: tab.url,
      title: tab.title || tab.url,
      description: '',
      categoryId: categoryId,
      createdAt: new Date().toISOString(),
      updatedAt: new Date().toISOString()
    };
  });
  
  // Create export data format
  const exportData = {
    urls: urlItems,
    categories: [],
    version: '1.0.0',
    exportedAt: new Date().toISOString()
  };
  
  // Copy to clipboard
  const jsonString = JSON.stringify(exportData);
  
  // Firefox doesn't support document.execCommand in background scripts
  // We'll use the clipboard API if available, or create a temporary element
  if (navigator.clipboard && navigator.clipboard.writeText) {
    return navigator.clipboard.writeText(jsonString).then(function() {
      showNotification(tabs.length);
    }).catch(function(error) {
      console.error('Error copying to clipboard:', error);
    });
  } else {
    // Fallback for older Firefox versions
    // This requires a content script with appropriate permissions
    console.error('Clipboard API not available in background script');
    // Still show notification
    showNotification(tabs.length);
  }
}

// Show notification
function showNotification(tabCount) {
  browser.notifications.create({
    type: 'basic',
    iconUrl: 'icons/icon128.png',
    title: 'Later',
    message: `${tabCount} tab(s) copied to clipboard. Paste into Later app to import.`
  });
}

// Generate a UUID
function generateId() {
  return 'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'.replace(/[xy]/g, function(c) {
    const r = Math.random() * 16 | 0;
    const v = c === 'x' ? r : (r & 0x3 | 0x8);
    return v.toString(16);
  });
}