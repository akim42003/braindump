const supabase_client = supabase.createClient(SUPABASE_URL, SUPABASE_ANON_KEY);

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
    } • ${post.category}</small>
    <div>${post.content}</div>
  `;
  return postElement;
}

async function loadPosts(append = false) {
  if (!append) {
    postsContainer.innerHTML = "";
    loadMoreBtn.style.display = "inline-block";
  }

  let query = supabase_client
    .from("Blog Posts")
    .select("*")
    .order("created_at", { ascending });

  if (currentCategory) {
    query = query.eq("category", currentCategory);
  }

  query = query.range(page * pageSize, (page + 1) * pageSize - 1);

  const { data: posts, error } = await query;
  if (error) {
    console.error("Error loading posts:", error);
    return;
  }

  // Append posts
  posts.forEach((post) => {
    postsContainer.appendChild(createPostElement(post));
  });

  // If fewer results than a full page, hide “Load More”
  if (!posts || posts.length < pageSize) {
    loadMoreBtn.style.display = "none";
  }
}

// initial fetch
loadPosts();
