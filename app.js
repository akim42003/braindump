const supabase_client = supabase.createClient(SUPABASE_URL, SUPABASE_ANON_KEY);

const postsContainer = document.getElementById("posts-container");

let page = 0;
const pageSize = 10;

document.getElementById("load-more-btn").addEventListener("click", () => {
  page++;
  loadPosts(true); // append=true
});

// Helper to create a post element
function createPostElement(post) {
  const postElement = document.createElement("div");
  postElement.classList.add("post");

  postElement.innerHTML = `
    <h2>${post.title}</h2>
    <small>${post.created_at ? new Date(post.created_at).toLocaleString() : post.date}</small>
    <div>${post.content}</div>
  `;

  return postElement;
}

// Load posts from Supabase
async function loadPosts() {
  const { data: posts, error } = await supabase_client
    .from("Blog Posts")
    .select("*")
    .order("created_at", { ascending: false })
    .range(page * pageSize, (page + 1) * pageSize - 1);

  postsContainer.innerHTML = "";

  if (error) {
    console.error("Error loading posts:", error);
    return;
  }

  posts.forEach((post) => {
    const postElement = createPostElement(post);
    postsContainer.appendChild(postElement);
  });
}

loadPosts();
