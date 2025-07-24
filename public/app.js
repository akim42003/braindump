const API_BASE_URL = window.location.hostname === 'localhost' ? 
  'http://localhost:8001/api' : 
  `http://${window.location.hostname}:8001/api`;

// Heartbeat to keep server alive
setInterval(async () => {
  try {
    const response = await fetch(`${API_BASE_URL.replace('/api', '')}/health`);
    const data = await response.json();
    console.log('Heartbeat:', data.database);
  } catch (error) {
    console.error('Heartbeat failed:', error);
  }
}, 45000); // Every 45 seconds

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

    const response = await fetch(url);
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
  }
}

// initial fetch
loadPosts();
