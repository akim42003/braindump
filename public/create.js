// create.js

// 1) Initialize your Supabase client
const supabase_client = supabase.createClient(SUPABASE_URL, SUPABASE_ANON_KEY);

// 2) Wire up the “Submit” button and auto‑resize on the content textarea
document.getElementById("submit-post").addEventListener("click", submitPost);

const contentInput = document.getElementById("content");
contentInput.addEventListener("input", autoResize);

function autoResize() {
  this.style.height = "auto";
  this.style.height = this.scrollHeight + "px";
}

// 3) Main submit handler
async function submitPost() {
  const titleEl = document.getElementById("title");
  const contentEl = document.getElementById("content");
  const categoryEl = document.getElementById("category");

  const title = titleEl.value.trim();
  const content = contentEl.value.trim();
  const category = categoryEl.value;

  if (!title || !content) {
    return alert("Please fill out both the title and content.");
  }

  // 4) Use supabase_client and destructure data & error
  const { data, error } = await supabase_client
    .from("Blog Posts")
    .insert([{ title, content, category }]);

  if (error) {
    console.error("Error inserting post:", error.message);
    alert("Failed to submit post.");
    return;
  }

  console.log("Post submitted:", data);

  // 5) Clear the form fields (including the category dropdown)
  titleEl.value = "";
  contentEl.value = "";
  contentEl.style.height = ""; // reset auto-resize
  categoryEl.selectedIndex = 0; // back to “Question” or whatever your first <option> is

  alert("Post created successfully!");

  // 6) Redirect back to index if you like:
  // window.location.href = "index.html";
}
