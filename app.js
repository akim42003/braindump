const posts = [
  {
    title: "First Blog Post",
    date: "2025-04-20",
    content: "This is the content of my first blog post!",
  },
  {
    title: "Another Day, Another Post",
    date: "2025-04-21",
    content: "Learning JavaScript is so much fun!",
  },
];

// Get the container where we want to insert posts
const postsContainer = document.getElementById("posts-container");

// Loop through posts and render them
posts.forEach((post) => {
  const postElement = document.createElement("div");
  postElement.classList.add("post");

  postElement.innerHTML = `
    <h2>${post.title}</h2>
    <small>${post.date}</small>
    <p>${post.content}</p>
  `;

  postsContainer.appendChild(postElement);
});
