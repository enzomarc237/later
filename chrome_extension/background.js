// Listen for keyboard shortcuts
chrome.commands.onCommand.addListener(function(command) {
  if (command === 'save_all_tabs') {
    saveAllTabs();
  } else if (command === '_execute_action') {
    saveCurrentTab();
  }
});

// Save current tab
function saveCurrentTab() {
  chrome.storage.sync.get('categories', function(data) {
    const categories = data.categories || [];
    
    // If no categories exist, create a default one
    if (categories.length === 0) {
      const defaultCategory = {
        id: generateId(),
        name: 'Bookmarks'
      };
      categories.push(defaultCategory);
      chrome.storage.sync.set({ categories: categories });
    }
    
    // Use the first category as default
    const categoryId = categories[0].id;
    
    chrome.tabs.query({ active: true, currentWindow: true }, function(tabs) {
      if (tabs.length === 0) {
        console.error('No active tab found');
        return;
      }
      
      const tab = tabs[0];
      saveTabToClipboard([tab], categoryId);
    });
  });
}

// Save all tabs
function saveAllTabs() {
  chrome.storage.sync.get('categories', function(data) {
    const categories = data.categories || [];
    
    // If no categories exist, create a default one
    if (categories.length === 0) {
      const defaultCategory = {
        id: generateId(),
        name: 'Bookmarks'
      };
      categories.push(defaultCategory);
      chrome.storage.sync.set({ categories: categories });
    }
    
    // Use the first category as default
    const categoryId = categories[0].id;
    
    chrome.tabs.query({ currentWindow: true }, function(tabs) {
      if (tabs.length === 0) {
        console.error('No tabs found');
        return;
      }
      
      saveTabToClipboard(tabs, categoryId);
    });
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
  
  // Create a temporary textarea element to copy text to clipboard
  const textArea = document.createElement('textarea');
  textArea.value = jsonString;
  document.body.appendChild(textArea);
  textArea.select();
  document.execCommand('copy');
  document.body.removeChild(textArea);
  
  // Show notification
  chrome.notifications.create({
    type: 'basic',
    iconUrl: 'icons/icon128.png',
    title: 'Later',
    message: `${tabs.length} tab(s) copied to clipboard. Paste into Later app to import.`
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