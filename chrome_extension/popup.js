document.addEventListener("DOMContentLoaded", function () {
  // DOM elements
  const categorySelect = document.getElementById("category");
  const newCategoryForm = document.getElementById("newCategoryForm");
  const newCategoryInput = document.getElementById("newCategory");
  const createCategoryBtn = document.getElementById("createCategory");
  const showNewCategoryLink = document.getElementById("showNewCategory");
  const saveCurrentTabBtn = document.getElementById("saveCurrentTab");
  const saveAllTabsBtn = document.getElementById("saveAllTabs");
  const statusDiv = document.getElementById("status");

  // Load categories from storage
  loadCategories();

  // Event listeners
  showNewCategoryLink.addEventListener("click", function (e) {
    e.preventDefault();
    newCategoryForm.classList.toggle("hidden");
    showNewCategoryLink.classList.toggle("hidden");
    newCategoryInput.focus();
  });

  createCategoryBtn.addEventListener("click", function () {
    createCategory();
  });

  newCategoryInput.addEventListener("keypress", function (e) {
    if (e.key === "Enter") {
      createCategory();
    }
  });

  saveCurrentTabBtn.addEventListener("click", function () {
    saveCurrentTab();
  });

  saveAllTabsBtn.addEventListener("click", function () {
    saveAllTabs();
  });

  // Functions
  function loadCategories() {
    chrome.storage.sync.get("categories", function (data) {
      let categories = data.categories || [];

      // If no categories exist, create a default one
      if (categories.length === 0) {
        categories = [{ id: generateId(), name: "Bookmarks" }];
        chrome.storage.sync.set({ categories: categories });
      }

      // Clear and populate the dropdown
      categorySelect.innerHTML = "";
      categories.forEach(function (category) {
        const option = document.createElement("option");
        option.value = category.id;
        option.textContent = category.name;
        categorySelect.appendChild(option);
      });
    });
  }

  function createCategory() {
    const categoryName = newCategoryInput.value.trim();

    if (categoryName) {
      chrome.storage.sync.get("categories", function (data) {
        const categories = data.categories || [];
        const newCategory = {
          id: generateId(),
          name: categoryName,
        };

        categories.push(newCategory);
        chrome.storage.sync.set({ categories: categories }, function () {
          // Reload categories and reset form
          loadCategories();
          newCategoryInput.value = "";
          newCategoryForm.classList.add("hidden");
          showNewCategoryLink.classList.remove("hidden");

          // Select the new category
          setTimeout(function () {
            categorySelect.value = newCategory.id;
          }, 100);
        });
      });
    }
  }

  function saveCurrentTab() {
    const categoryId = categorySelect.value;

    if (!categoryId) {
      showStatus("Please select a category", "error");
      return;
    }

    chrome.tabs.query({ active: true, currentWindow: true }, function (tabs) {
      if (tabs.length === 0) {
        showStatus("No active tab found", "error");
        return;
      }

      const tab = tabs[0];
      saveTabsToLater([tab], categoryId);
    });
  }

  function saveAllTabs() {
    const categoryId = categorySelect.value;

    if (!categoryId) {
      showStatus("Please select a category", "error");
      return;
    }

    chrome.tabs.query({ currentWindow: true }, function (tabs) {
      if (tabs.length === 0) {
        showStatus("No tabs found", "error");
        return;
      }

      saveTabsToLater(tabs, categoryId);
    });
  }

  function saveTabsToLater(tabs, categoryId) {
    const urlItems = tabs.map((tab) => {
      return {
        id: generateId(),
        url: tab.url,
        title: tab.title || tab.url,
        description: "",
        categoryId: categoryId,
        createdAt: new Date().toISOString(),
        updatedAt: new Date().toISOString(),
      };
    });

    // Get categories from storage and include them in the export data
    chrome.storage.sync.get("categories", function (data) {
      const categories = data.categories || [];

      // Format categories to match the expected format in the macOS app
      const formattedCategories = categories.map((category) => {
        return {
          id: category.id,
          name: category.name,
          createdAt: category.createdAt || new Date().toISOString(),
          updatedAt: category.updatedAt || new Date().toISOString(),
        };
      });

      // Create export data format with categories
      const exportData = {
        urls: urlItems,
        categories: formattedCategories,
        version: "1.0.0",
        exportedAt: new Date().toISOString(),
      };

      // Try to open with Later app using URL scheme
      openWithLaterApp(exportData, tabs.length).then((success) => {
        if (!success) {
          // Fallback to clipboard if URL scheme fails
          copyToClipboard(exportData, tabs.length);
        }
      });
    });
  }

  function openWithLaterApp(exportData, tabCount) {
    return new Promise((resolve) => {
      // Get category name for the selected category
      chrome.storage.sync.get("categories", function (data) {
        const categories = data.categories || [];
        const selectedCategory = categories.find(
          (cat) => cat.id === categorySelect.value,
        );
        const categoryName = selectedCategory ? selectedCategory.name : "";

        if (exportData.urls.length === 1) {
          // For a single URL, use the simpler /add endpoint
          const url = exportData.urls[0];
          const laterUrl = `later:///add?url=${encodeURIComponent(
            url.url,
          )}&title=${encodeURIComponent(
            url.title,
          )}&category=${encodeURIComponent(categoryName)}`;

          // Show status message before navigating
          showStatus(`${tabCount} tab(s) sent to Later app.`, "success");

          // Use simple window.location to open URL scheme
          // This will close the popup but trigger the scheme handler
          setTimeout(() => {
            window.location.href = laterUrl;
          }, 300); // Short delay to ensure status message is shown

          resolve(true);
        } else {
          // For multiple URLs, use the /import endpoint with JSON data
          const jsonString = JSON.stringify(exportData);
          const laterUrl = `later:///import?data=${encodeURIComponent(
            jsonString,
          )}`;

          // Check if the URL is too long (browsers have limits)
          if (laterUrl.length > 2000) {
            // Fallback to clipboard for large data
            resolve(false);
            return;
          }

          // Show status message before navigating
          showStatus(`${tabCount} tab(s) sent to Later app.`, "success");

          // Use simple window.location to open URL scheme
          // This will close the popup but trigger the scheme handler
          setTimeout(() => {
            window.location.href = laterUrl;
          }, 300); // Short delay to ensure status message is shown

          resolve(true);
        }
      });
    });
  }

  function copyToClipboard(exportData, tabCount) {
    // Copy to clipboard as fallback
    const jsonString = JSON.stringify(exportData);
    navigator.clipboard
      .writeText(jsonString)
      .then(function () {
        showStatus(
          `${tabCount} tab(s) copied to clipboard. Paste into Later app to import.`,
          "success",
        );
      })
      .catch(function (err) {
        console.error("Could not copy text: ", err);
        showStatus("Failed to copy to clipboard", "error");
      });
  }

  function showStatus(message, type) {
    statusDiv.textContent = message;
    statusDiv.className = "status " + type;

    // Clear status after 3 seconds
    setTimeout(function () {
      statusDiv.className = "status";
    }, 3000);
  }

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
});
