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

function showStatus(message, type) {
  const statusDiv = document.getElementById("status");
  statusDiv.textContent = message;
  statusDiv.className = "status " + type;

  // Clear status after 3 seconds
  setTimeout(function () {
    statusDiv.className = "status";
  }, 3000);
}

function initializePopup(browserAPI) {
  // DOM elements
  const categorySelect = document.getElementById("category");
  const newCategoryForm = document.getElementById("newCategoryForm");
  const newCategoryInput = document.getElementById("newCategory");
  const createCategoryBtn = document.getElementById("createCategory");
  const showNewCategoryLink = document.getElementById("showNewCategory");
  const saveCurrentTabBtn = document.getElementById("saveCurrentTab");
  const saveAllTabsBtn = document.getElementById("saveAllTabs");

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
    browserAPI.storage.sync.get("categories").then(function (data) {
      let categories = data.categories || [];

      // If no categories exist, create a default one
      if (categories.length === 0) {
        categories = [{ id: generateId(), name: "Bookmarks" }];
        browserAPI.storage.sync.set({ categories: categories });
      }

      // Clear and populate the dropdown
      categorySelect.innerHTML = "";
      categories.forEach(function (category) {
        const option = document.createElement("option");
        option.value = category.id;
        option.textContent = category.name;
        categorySelect.appendChild(option);
      });
    }).catch(function (error) {
      console.error("Error loading categories:", error);
    });
  }

  function createCategory() {
    const categoryName = newCategoryInput.value.trim();

    if (categoryName) {
      browserAPI.storage.sync.get("categories").then(function (data) {
        const categories = data.categories || [];
        const newCategory = {
          id: generateId(),
          name: categoryName,
          createdAt: new Date().toISOString(),
          updatedAt: new Date().toISOString(),
        };

        categories.push(newCategory);
        browserAPI.storage.sync.set({ categories: categories }).then(function () {
          // Reload categories and reset form
          loadCategories();
          newCategoryInput.value = "";
          newCategoryForm.classList.add("hidden");
          showNewCategoryLink.classList.remove("hidden");

          // Select the new category
          setTimeout(function () {
            categorySelect.value = newCategory.id;
          }, 100);
        }).catch(function (error) {
          console.error("Error setting categories:", error);
          showStatus("Failed to create category", "error");
        });
      }).catch(function (error) {
        console.error("Error getting categories:", error);
        showStatus("Failed to create category", "error");
      });
    }
  }

  function saveCurrentTab() {
    browserAPI.tabs.query({ active: true, currentWindow: true }).then(function (tabs) {
      if (tabs.length === 0) {
        showStatus("No active tab found.", "error");
        return;
      }
      saveTabsToLater(tabs);
    }).catch(function (error) {
      console.error("Error querying tabs:", error);
      showStatus("Failed to save current tab.", "error");
    });
  }

  function saveAllTabs() {
    browserAPI.tabs.query({ currentWindow: true }).then(function (tabs) {
      if (tabs.length === 0) {
        showStatus("No tabs found in the current window.", "error");
        return;
      }
      saveTabsToLater(tabs);
    }).catch(function (error) {
      console.error("Error querying tabs:", error);
      showStatus("Failed to save all tabs.", "error");
    });
  }

  function saveTabsToLater(tabs) {
    const urlItems = tabs.map((tab) => {
      return {
        id: generateId(),
        url: tab.url,
        title: tab.title || tab.url,
        description: "",
        categoryId: categorySelect.value,
        createdAt: new Date().toISOString(),
        updatedAt: new Date().toISOString(),
      };
    });

    browserAPI.storage.sync.get("categories").then(function (data) {
      const categories = data.categories || [];
      const formattedCategories = categories.map((category) => {
        return {
          id: category.id,
          name: category.name,
          createdAt: category.createdAt || new Date().toISOString(),
          updatedAt: category.updatedAt || new Date().toISOString(),
        };
      });

      const exportData = {
        urls: urlItems,
        categories: formattedCategories,
        version: "1.0.0",
        exportedAt: new Date().toISOString(),
      };

      copyToClipboard(exportData, tabs.length, false);
      triggerClipboardImport(exportData, tabs.length);
    }).catch((error) => {
      console.error("Error in saveTabsToLater:", error);
      const fallbackExportData = {
        urls: urlItems,
        categories: [],
        version: "1.0.0",
        exportedAt: new Date().toISOString(),
      };
      copyToClipboard(fallbackExportData, tabs.length);
    });
  }

  function triggerClipboardImport(exportData, tabCount) {
    const laterUrl = `later:///clipboard-import`;
    showStatus(`${tabCount} tab(s) sent to Later app.`, "success");
    setTimeout(() => {
      window.location.href = laterUrl;
    }, 300);
  }
