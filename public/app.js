const API_BASE_URL = window.location.hostname === 'localhost' ? 
  'http://localhost:8001/api' : 
  `/api`; // Use nginx proxy when not on localhost

// Connection status management
let connectionStatus = 'unknown';
let heartbeatFailures = 0;
const maxHeartbeatFailures = 3;

// Add connection status indicator to UI
function updateConnectionStatus(status) {
  connectionStatus = status;
  const indicator = document.getElementById('connection-status');
  if (!indicator) {
    const statusDiv = document.createElement('div');
    statusDiv.id = 'connection-status';
    statusDiv.style.cssText = 'position: fixed; top: 10px; right: 10px; padding: 5px 10px; border-radius: 5px; font-size: 12px; z-index: 1000;';
    document.body.appendChild(statusDiv);
  }
  
  const statusElement = document.getElementById('connection-status');
  switch(status) {
    case 'connected':
      statusElement.style.backgroundColor = '#4CAF50';
      statusElement.style.color = 'white';
      statusElement.textContent = '● Connected';
      heartbeatFailures = 0;
      break;
    case 'disconnected':
      statusElement.style.backgroundColor = '#f44336';
      statusElement.style.color = 'white';
      statusElement.textContent = '● Disconnected';
      break;
    case 'reconnecting':
      statusElement.style.backgroundColor = '#ff9800';
      statusElement.style.color = 'white';
      statusElement.textContent = '● Reconnecting...';
      break;
  }
}

// Enhanced heartbeat with retry logic
async function sendHeartbeat() {
  try {
    const healthURL = window.location.hostname === 'localhost' ? 
      'http://localhost:8001/health' : 
      '/health'; // Use nginx proxy when not on localhost
    const response = await fetch(healthURL, {
      method: 'GET',
      timeout: 10000 // 10 second timeout
    });
    
    if (response.ok) {
      const data = await response.json();
      console.log('Heartbeat:', data);
      updateConnectionStatus('connected');
    } else {
      throw new Error(`HTTP ${response.status}`);
    }
  } catch (error) {
    heartbeatFailures++;
    console.error(`Heartbeat failed (${heartbeatFailures}/${maxHeartbeatFailures}):`, error.message);
    
    if (heartbeatFailures >= maxHeartbeatFailures) {
      updateConnectionStatus('disconnected');
      // Increase heartbeat frequency when disconnected
      setTimeout(sendHeartbeat, 2000); // Retry in 2 seconds for faster recovery
    } else {
      updateConnectionStatus('reconnecting');
    }
  }
}

// Start heartbeat - aggressive 10 second interval to prevent any timeout
setInterval(sendHeartbeat, 10000);
sendHeartbeat(); // Initial heartbeat

// 2. DOM refs
const postsContainer = document.getElementById("posts-container");
const loadMoreBtn = document.getElementById("load-more-btn");
const filterBar = document.getElementById("filter-bar");

let page = 0;
const pageSize = 10;
let currentCategory = ""; // '' means “All”
let ascending = false; // false = newest first

loadMoreBtn.addEventListener("click", () => {
  page++;
  loadPosts(true); // append = true
});

//  Event: Category filter
filterBar.addEventListener("click", (event) => {
  if (event.target.tagName !== "BUTTON") return;
  // Highlight active button
  filterBar
    .querySelectorAll("button")
    .forEach((button) => button.classList.remove("active"));
  event.target.classList.add("active");

  // Update filter and reset paging
  currentCategory = event.target.dataset.cat || "";
  page = 0;
  loadPosts(false);
});

//  Helper: create a post DOM node
function createPostElement(post) {
  const postElement = document.createElement("div");
  postElement.classList.add("post", post.category);

  postElement.innerHTML = `
    <h2>${post.title}</h2>
    <small>${
      post.created_at ? new Date(post.created_at).toLocaleString() : post.date
    } - ${post.category}</small>
    <div>${post.content}</div>
  `;
  return postElement;
}

// Fetch with retry logic
async function fetchWithRetry(url, options = {}, maxRetries = 3) {
  let lastError;
  
  for (let i = 0; i < maxRetries; i++) {
    try {
      const response = await fetch(url, {
        ...options,
        signal: AbortSignal.timeout(15000) // 15 second timeout
      });
      
      if (!response.ok && response.status === 503) {
        // Server is temporarily unavailable, wait and retry
        const delay = Math.min(1000 * Math.pow(2, i), 10000); // Exponential backoff
        console.log(`Server unavailable, retrying in ${delay}ms...`);
        await new Promise(resolve => setTimeout(resolve, delay));
        continue;
      }
      
      return response;
    } catch (error) {
      lastError = error;
      if (i < maxRetries - 1) {
        const delay = Math.min(1000 * Math.pow(2, i), 10000);
        console.log(`Request failed, retrying in ${delay}ms...`);
        await new Promise(resolve => setTimeout(resolve, delay));
      }
    }
  }
  
  throw lastError || new Error('Max retries exceeded');
}

async function loadPosts(append = false) {
  if (!append) {
    postsContainer.innerHTML = "";
    loadMoreBtn.style.display = "inline-block";
  }

  try {
    let url = `${API_BASE_URL}/posts?page=${page}&limit=${pageSize}&ascending=${ascending}`;
    
    if (currentCategory) {
      url += `&category=${currentCategory}`;
    }

    const response = await fetchWithRetry(url);
    if (!response.ok) {
      throw new Error(`HTTP error! status: ${response.status}`);
    }
    
    const posts = await response.json();

    // Append posts
    posts.forEach((post) => {
      postsContainer.appendChild(createPostElement(post));
    });

    // If fewer results than a full page, hide "Load More"
    if (!posts || posts.length < pageSize) {
      loadMoreBtn.style.display = "none";
    }
  } catch (error) {
    console.error("Error loading posts:", error);
    // Show error message to user
    if (postsContainer.children.length === 0) {
      postsContainer.innerHTML = '<div style="text-align: center; padding: 20px; color: #666;">Failed to load posts. Please check your connection and try again.</div>';
    }
  }
}

// initial fetch
loadPosts();
