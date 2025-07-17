const API_BASE_URL = window.location.hostname === 'localhost' ? 
  'http://localhost:3000/api' : 
  `http://${window.location.hostname}:3000/api`;

document.getElementById("submit-post").addEventListener("click", submitPost);

const contentInput = document.getElementById("content");
contentInput.addEventListener("input", autoResize);

function autoResize() {
  this.style.height = "auto";
  this.style.height = this.scrollHeight + "px";
}

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

  try {
    const response = await fetch(`${API_BASE_URL}/posts`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({ title, content, category }),
    });

    if (!response.ok) {
      throw new Error(`HTTP error! status: ${response.status}`);
    }

    const data = await response.json();
    console.log("Post submitted:", data);

    //  Clear the form fields (including the category dropdown)
    titleEl.value = "";
    contentEl.value = "";
    contentEl.style.height = ""; // reset auto-resize
    categoryEl.selectedIndex = 0; // back to "Question" or whatever your first <option> is

    alert("Post created successfully!");

    //  Redirect back to index option
    // window.location.href = "index.html";
  } catch (error) {
    console.error("Error inserting post:", error.message);
    alert("Failed to submit post.");
  }
}
