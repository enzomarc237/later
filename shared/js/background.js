function generateId() {
  return "xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx".replace(
    /[xy]/g,
    function (c) {
      const r = (Math.random() * 16) | 0;
      const v = c === "x" ? r : (r & 0x3) | 0x8;
      return v.toString(16);
    },
  );
}

function initializeBackground(browserAPI) {
  // Listen for keyboard shortcuts
  browserAPI.commands.onCommand.addListener(function (command) {
    if (command === "save_all_tabs") {
      saveAllTabs();
    } else if (command === "_execute_action" || command === "_execute_browser_action") {
      saveCurrentTab();
    }
  });

  // Save current tab
  function saveCurrentTab() {
    browserAPI.storage.sync.get("categories").then(function (data) {
      const categories = data.categories || [];

      // If no categories exist, create a default one
      if (categories.length === 0) {
        const defaultCategory = {
          id: generateId(),
          name: "Bookmarks",
          createdAt: new Date().toISOString(),
          updatedAt: new Date().toISOString(),
        };
        categories.push(defaultCategory);
        return browserAPI.storage.sync.set({ categories: categories }).then(function () {
          return categories;
        });
      }

      return categories;
    }).then(function (categories) {
      // Use the first category as default
      const categoryId = categories[0].id;

      return browserAPI.tabs.query({ active: true, currentWindow: true }).then(function (tabs) {
        if (tabs.length === 0) {
          console.error("No active tab found");
          return;
        }

        const tab = tabs[0];
        return saveTabToClipboard([tab], categoryId);
      });
    }).catch(function (error) {
      console.error("Error in saveCurrentTab:", error);
    });
  }

  // Save all tabs
  function saveAllTabs() {
    browserAPI.storage.sync.get("categories").then(function (data) {
      const categories = data.categories || [];

      // If no categories exist, create a default one
      if (categories.length === 0) {
        const defaultCategory = {
          id: generateId(),
          name: "Bookmarks",
          createdAt: new Date().toISOString(),
          updatedAt: new Date().toISOString(),
        };
        categories.push(defaultCategory);
        return browserAPI.storage.sync.set({ categories: categories }).then(function () {
          return categories;
        });
      }

      return categories;
    }).then(function (categories) {
      // Use the first category as default
      const categoryId = categories[0].id;

      return browserAPI.tabs.query({ currentWindow: true }).then(function (tabs) {
        if (tabs.length === 0) {
          console.error("No tabs found");
          return;
        }

        return saveTabToClipboard(tabs, categoryId);
      });
    }).catch(function (error) {
      console.error("Error in saveAllTabs:", error);
    });
  }

  // Save tabs to clipboard
  function saveTabToClipboard(tabs, categoryId) {
    const urlItems = tabs.map((tab) => {
      return {
