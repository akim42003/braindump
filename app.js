const supabase_client = supabase.createClient(SUPABASE_URL, SUPABASE_ANON_KEY);

const postsContainer = document.getElementById("posts-container");

// Helper to create a post element
function createPostElement(post) {
  const postElement = document.createElement("div");
  postElement.classList.add("post");

  postElement.innerHTML = `
    <h2>${post.title}</h2>
    <small>${post.created_at ? new Date(post.created_at).toLocaleDateString() : post.date}</small>
    <div>${post.content}</div>
  `;

  return postElement;
}

// Load posts from Supabase
async function loadPosts() {
  const { data: posts, error } = await supabase_client
    .from("Blog Posts")
    .select("*")
    .order("created_at", { ascending: false });

  postsContainer.innerHTML = "";

  if (error) {
    console.error("Error loading posts:", error);
    return;
  }

  posts.forEach((post) => {
    const postElement = createPostElement(post);
    postsContainer.appendChild(postElement);
  });

  //   staticPosts.forEach((post) => {
  //     const postElement = createPostElement(post);
  //     postsContainer.appendChild(postElement);
  //   });
}

loadPosts();
