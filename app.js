const posts = [
  {
    title: "First Post",
    date: "2025-04-20",
    content: `
    <p>
      Alright so I guess I started this thing sort of to practice my frontend.
      More so I think I needed a better place to store my thoughts about technology, AI and math that
      isn't on paper.
    </p>
    <p>
      So here's what I was thinking about earlier today before starting this. I was working on my
      AI assistant (SOFIA as it will be refered to) and it kept hallucinating emails. I thought it was
      interesting how hallucination has been much more prevalent with these smaller models although I suppose
      it is to be expected. In other news I need to find a more elgant solution to store this than
      JavaScript arrays. Maybe a markdown interpreter in browser is a good place to start.
      </p> `,
  },
];

const postsContainer = document.getElementById("posts-container");

posts.forEach((post) => {
  const postElement = document.createElement("div");
  postElement.classList.add("post");

  postElement.innerHTML = `
    <h2>${post.title}</h2>
    <small>${post.date}</small>
    <div>${post.content}</div>
  `;

  postsContainer.appendChild(postElement);
});
