document.addEventListener('DOMContentLoaded', function() {
  // DOM elements
  const categorySelect = document.getElementById('category');
  const newCategoryForm = document.getElementById('newCategoryForm');
  const newCategoryInput = document.getElementById('newCategory');
  const createCategoryBtn = document.getElementById('createCategory');
  const showNewCategoryLink = document.getElementById('showNewCategory');
  const saveCurrentTabBtn = document.getElementById('saveCurrentTab');
  const saveAllTabsBtn = document.getElementById('saveAllTabs');
  const statusDiv = document.getElementById('status');
  
  // Load categories from storage
  loadCategories();
  
  // Event listeners
  showNewCategoryLink.addEventListener('click', function(e) {
    e.preventDefault();
    newCategoryForm.classList.toggle('hidden');
    showNewCategoryLink.classList.toggle('hidden');
    newCategoryInput.focus();
  });
  
  createCategoryBtn.addEventListener('click', function() {
    createCategory();
  });
  
  newCategoryInput.addEventListener('keypress', function(e) {
    if (e.key === 'Enter') {
      createCategory();
    }
  });
  
  saveCurrentTabBtn.addEventListener('click', function() {
    saveCurrentTab();
  });
  
  saveAllTabsBtn.addEventListener('click', function() {
    saveAllTabs();
  });
  
  // Functions
  function loadCategories() {
    browser.storage.sync.get('categories').then(function(data) {
      let categories = data.categories || [];
      
      // If no categories exist, create a default one
      if (categories.length === 0) {
        categories = [
          { id: generateId(), name: 'Bookmarks' }
        ];
        browser.storage.sync.set({ categories: categories });
      }
      
      // Clear and populate the dropdown
      categorySelect.innerHTML = '';
      categories.forEach(function(category) {
        const option = document.createElement('option');
        option.value = category.id;
        option.textContent = category.name;
        categorySelect.appendChild(option);
      });
    }).catch(function(error) {
      console.error('Error loading categories:', error);
    });
  }
  
  function createCategory() {
    const categoryName = newCategoryInput.value.trim();
    
    if (categoryName) {
      browser.storage.sync.get('categories').then(function(data) {
        const categories = data.categories || [];
        const newCategory = {
          id: generateId(),
          name: categoryName
        };
        
        categories.push(newCategory);
        return browser.storage.sync.set({ categories: categories }).then(function() {
          // Reload categories and reset form
          loadCategories();
          newCategoryInput.value = '';
          newCategoryForm.classList.add('hidden');
          showNewCategoryLink.classList.remove('hidden');
          
          // Select the new category
          setTimeout(function() {
            categorySelect.value = newCategory.id;
          }, 100);
        });
      }).catch(function(error) {
        console.error('Error creating category:', error);
      });
    }
  }
  
  function saveCurrentTab() {
    const categoryId = categorySelect.value;
    
    if (!categoryId) {
      showStatus('Please select a category', 'error');
      return;
    }
    
    browser.tabs.query({ active: true, currentWindow: true }).then(function(tabs) {
      if (tabs.length === 0) {
        showStatus('No active tab found', 'error');
        return;
      }
      
      const tab = tabs[0];
      saveTabToClipboard([tab], categoryId);
    }).catch(function(error) {
      console.error('Error querying tabs:', error);
    });
  }
  
  function saveAllTabs() {
    const categoryId = categorySelect.value;
    
    if (!categoryId) {
      showStatus('Please select a category', 'error');
      return;
    }
    
    browser.tabs.query({ currentWindow: true }).then(function(tabs) {
      if (tabs.length === 0) {
        showStatus('No tabs found', 'error');
        return;
      }
      
      saveTabToClipboard(tabs, categoryId);
    }).catch(function(error) {
      console.error('Error querying tabs:', error);
    });
  }
  
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
    navigator.clipboard.writeText(jsonString).then(function() {
      showStatus(`${tabs.length} tab(s) copied to clipboard. Paste into Later app to import.`, 'success');
    }).catch(function(err) {
      console.error('Could not copy text: ', err);
      showStatus('Failed to copy to clipboard', 'error');
    });
  }
  
  function showStatus(message, type) {
    statusDiv.textContent = message;
    statusDiv.className = 'status ' + type;
    
    // Clear status after 3 seconds
    setTimeout(function() {
      statusDiv.className = 'status';
    }, 3000);
  }
  
  function generateId() {
    return 'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'.replace(/[xy]/g, function(c) {
      const r = Math.random() * 16 | 0;
      const v = c === 'x' ? r : (r & 0x3 | 0x8);
      return v.toString(16);
    });
  }
});