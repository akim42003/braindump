const supabase_client = supabase.createClient(SUPABASE_URL, SUPABASE_ANON_KEY);

document.getElementById("submit-post").addEventListener("click", submitPost);

const contentInput = document.getElementById("content");
contentInput.addEventListener("input", autoResize);

function autoResize() {
  this.style.height = "auto"; // reset the height
  this.style.height = this.scrollHeight + "px"; // set to full content height
}

async function submitPost() {
  console.log("test");
  const title = document.getElementById("title").value.trim();
  const content = document.getElementById("content").value.trim();

  if (!title || !content) {
    alert("Please fill out both the title and content.");
    return;
  }

  const { data, error } = await supabase_client
    .from("Blog Posts")
    .insert([{ title, content }]);

  if (error) {
    console.error("Error inserting post:", error.message);
    alert("Failed to submit post.");
  } else {
    console.log("Post submitted:", data);

    // Optionally clear form
    document.getElementById("title").value = "";
    document.getElementById("content").value = "";

    alert("Post created successfully!");

    // Optionally redirect to main blog page
    // window.location.href = "index.html";
  }
}
