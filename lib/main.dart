
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>SHADOW MUSIC</title>

<style>
* { box-sizing: border-box; }

body {
  margin: 0;
  background: #090b12;
  color: #f4f5ff;
  font-family: Arial, sans-serif;
}

header {
  padding: 25px 20px;
  background: #111522;
  border-bottom: 1px solid #292e42;
}

.logo {
  font-size: 25px;
  font-weight: 900;
  letter-spacing: 2px;
}

.logo span { color: #8b7cff; }

.subtitle {
  color: #9298ae;
  font-size: 12px;
  margin-top: 7px;
}

main {
  max-width: 600px;
  margin: auto;
  padding: 22px 17px;
}

h2 { font-size: 20px; }

.description {
  color: #a3a8ba;
  line-height: 1.6;
  font-size: 14px;
}

input {
  width: 100%;
  padding: 16px;
  background: #151927;
  color: white;
  border: 1px solid #343951;
  border-radius: 12px;
  outline: none;
  margin: 12px 0;
  font-size: 14px;
}

button {
  padding: 14px;
  border: 0;
  border-radius: 10px;
  cursor: pointer;
  font-weight: bold;
  font-size: 14px;
}

.primary {
  width: 100%;
  background: #8b7cff;
  color: #080914;
}

.secondary {
  background: #20253a;
  color: white;
  flex: 1;
}

.player {
  margin-top: 20px;
  background: #141827;
  padding: 12px;
  border-radius: 15px;
}

iframe {
  width: 100%;
  aspect-ratio: 16 / 9;
  border: 0;
  border-radius: 10px;
}

.actions {
  display: flex;
  gap: 10px;
  margin-top: 12px;
}

.section-title {
  margin-top: 28px;
  padding-bottom: 12px;
  border-bottom: 1px solid #282d40;
}

.saved-item {
  display: flex;
  align-items: center;
  gap: 8px;
  margin-top: 10px;
  padding: 12px;
  background: #151927;
  border-radius: 10px;
  overflow-wrap: anywhere;
}

.saved-item button {
  flex-shrink: 0;
  padding: 9px;
  background: #282e43;
  color: white;
}

#status {
  font-size: 13px;
  color: #b4aaff;
  margin-top: 12px;
  overflow-wrap: anywhere;
}

footer {
  text-align: center;
  padding: 25px;
  color: #727990;
  font-size: 12px;
}
</style>
</head>

<body>
<header>
  <div class="logo">SHADOW <span>MUSIC</span></div>
  <div class="subtitle">YOUR MUSIC SPACE</div>
</header>

<main>
  <h2>Music Player</h2>
  <p class="description">
    Paste a YouTube link to play music and save your
    favorite videos for later.
  </p>

  <input id="url"
         type="url"
         placeholder="Paste YouTube URL here">

  <button class="primary" onclick="playVideo()">
    PLAY MUSIC
  </button>

  <div id="status"></div>

  <section class="player" id="player" hidden>
    <iframe id="video"
      allow="autoplay; encrypted-media; picture-in-picture"
      allowfullscreen>
    </iframe>

    <div class="actions">
      <button class="secondary" onclick="saveVideo()">
        SAVE FAVORITE
      </button>
      <button class="secondary" onclick="openYoutube()">
        OPEN YOUTUBE
      </button>
    </div>
  </section>

  <h2 class="section-title">My Favorites</h2>
  <div id="favorites"></div>
</main>

<footer>SHADOW MUSIC · PERSONAL MUSIC PLAYER</footer>

<script>
let currentId = "";

function getVideoId(input) {
  try {
    const u = new URL(input.trim());

    if (u.hostname === "youtu.be" ||
        u.hostname === "www.youtu.be") {
      return u.pathname.split("/").filter(Boolean)[0] || "";
    }

    if ([
      "youtube.com", "www.youtube.com",
      "m.youtube.com", "music.youtube.com"
    ].includes(u.hostname)) {
      if (u.pathname === "/watch") {
        return u.searchParams.get("v") || "";
      }

      const parts = u.pathname.split("/").filter(Boolean);

      if (["embed", "shorts", "live"].includes(parts[0])) {
        return parts[1] || "";
      }
    }
  } catch (e) {}

  return "";
}

function playVideo(id) {
  if (typeof id !== "string") {
    id = getVideoId(document.getElementById("url").value);
  }

  if (!/^[a-zA-Z0-9_-]{11}$/.test(id)) {
    document.getElementById("status").textContent =
      "Please enter a valid YouTube video link.";
    return;
  }

  currentId = id;

  document.getElementById("video").src =
    "https://www.youtube.com/embed/" +
    encodeURIComponent(id);

  document.getElementById("player").hidden = false;
  document.getElementById("status").textContent =
    "Video ready to play.";
}

function openYoutube() {
  if (currentId) {
    window.open(
      "https://www.youtube.com/watch?v=" +
      encodeURIComponent(currentId),
      "_blank"
    );
  }
}

function getFavorites() {
  try {
    return JSON.parse(
      localStorage.getItem("shadow_music_favorites") || "[]"
    );
  } catch (e) {
    return [];
  }
}

function saveVideo() {
  if (!currentId) return;

  let items = getFavorites();

  if (!items.includes(currentId)) {
    items.unshift(currentId);

    try {
      localStorage.setItem(
        "shadow_music_favorites",
        JSON.stringify(items.slice(0, 100))
      );
    } catch (e) {
      document.getElementById("status").textContent =
        "Storage unavailable in this environment.";
      return;
    }
  }

  renderFavorites();
  document.getElementById("status").textContent =
    "Favorite saved.";
}

function removeFavorite(id) {
  const items = getFavorites().filter(item => item !== id);

  localStorage.setItem(
    "shadow_music_favorites",
    JSON.stringify(items)
  );

  renderFavorites();
}

function renderFavorites() {
  const container = document.getElementById("favorites");
  container.replaceChildren();

  const items = getFavorites();

  if (!items.length) {
    container.textContent = "No saved favorites yet.";
    container.style.color = "#9298ae";
    return;
  }

  items.forEach(id => {
    const row = document.createElement("div");
    row.className = "saved-item";

    const play = document.createElement("button");
    play.textContent = "PLAY";
    play.onclick = () => playVideo(id);

    const link = document.createElement("span");
    link.textContent = id;
    link.style.flex = "1";

    const remove = document.createElement("button");
    remove.textContent = "DELETE";
    remove.onclick = () => removeFavorite(id);

    row.append(play, link, remove);
    container.appendChild(row);
  });
}

renderFavorites();
</script>
</body>
</html>
