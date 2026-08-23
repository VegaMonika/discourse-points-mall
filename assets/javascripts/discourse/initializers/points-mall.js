import { apiInitializer } from "discourse/lib/api";
import { i18n } from "discourse-i18n";

function currentUser(api) {
  return api.getCurrentUser?.() || api.container?.lookup?.("service:current-user");
}

function usernameFromApi(api) {
  return currentUser(api)?.username;
}

let activeFrameState = {};
let avatarRefreshTimer;
const AVATAR_IMAGE_SELECTOR = 'img.avatar, img[src*="/user_avatar/"]';

function clearAvatarFrames() {
  document
    .querySelectorAll("img.jn-avatar-frame-neon-aqua")
    .forEach((node) => node.classList.remove("jn-avatar-frame-neon-aqua"));
  document
    .querySelectorAll("img.jn-avatar-frame-chibi-compact")
    .forEach((node) => node.classList.remove("jn-avatar-frame-chibi-compact"));
  document
    .querySelectorAll(".jn-avatar-frame-overlay")
    .forEach((node) => node.remove());
  document.querySelectorAll("img[data-jn-avatar-frame]").forEach((node) => {
    delete node.dataset.jnAvatarFrame;
  });
  document.querySelectorAll(".jn-avatar-frame-host").forEach((node) => {
    node.classList.remove(
      "jn-avatar-frame-host",
      "jn-avatar-frame-host-image",
      "jn-avatar-frame-host-chibi-blue-heart",
      "jn-avatar-frame-host-chibi-compact",
      "jn-avatar-frame-host-chibi-feature",
      "jn-avatar-frame-host-chibi-cluster"
    );
  });
}

function applyThemeSkin(themeSkin) {
  const root = document.documentElement;
  root.dataset.jnThemeSkin = themeSkin || "";
  root.classList.toggle("jn-theme-skin-starrail-neon", themeSkin === "starrail_neon");
}

function avatarBelongsToUser(img, username) {
  const normalized = encodeURIComponent(username.toLowerCase());
  const src = (img.getAttribute("src") || "").toLowerCase();

  return (
    img.closest(".header-dropdown-toggle.current-user") ||
    img.closest(".current-user") ||
    src.includes(`/${normalized}/`) ||
    src.includes(`/${username.toLowerCase()}/`)
  );
}

function chibiFrameTier(img) {
  const size = Math.max(
    img.getBoundingClientRect().width,
    img.getBoundingClientRect().height,
    img.width || 0,
    img.height || 0,
    Number.parseFloat(img.getAttribute("width")) || 0,
    Number.parseFloat(img.getAttribute("height")) || 0
  );

  if (
    size >= 56 &&
    img.closest(
      ".post-avatar .main-avatar, .user-profile-avatar, .user-card-avatar"
    )
  ) {
    return "feature";
  }

  if (img.closest(".topic-map, .topic-participants, .participant-list")) {
    return "cluster";
  }

  return "compact";
}

function positionImageAvatarFrames() {
  document
    .querySelectorAll(".jn-avatar-frame-overlay-image")
    .forEach((overlay) => {
      const host = overlay.parentElement;
      const img = host?.querySelector("img[data-jn-avatar-frame]");
      if (!img?.isConnected || !host?.isConnected) {
        return;
      }

      const imageRect = img.getBoundingClientRect();
      const hostRect = host.getBoundingClientRect();
      const avatarSize = Math.max(imageRect.width, imageRect.height);
      if (!avatarSize) {
        return;
      }

      const isCluster = overlay.classList.contains(
        "jn-avatar-frame-overlay-chibi-cluster"
      );
      const isCompact = overlay.classList.contains(
        "jn-avatar-frame-overlay-chibi-compact"
      );
      const frameScale = isCluster ? 1.18 : isCompact ? 1.38 : 1.5;
      const frameSize = avatarSize * frameScale;
      overlay.style.width = `${frameSize}px`;
      overlay.style.height = `${frameSize}px`;
      overlay.style.left = `${imageRect.left - hostRect.left + imageRect.width / 2}px`;
      overlay.style.top = `${imageRect.top - hostRect.top + imageRect.height / 2}px`;
    });
}

function addImageAvatarFrame(img, frame, frameUrl) {
  if (img.dataset.jnAvatarFrame === frame) {
    return;
  }

  const tier = chibiFrameTier(img);
  img.dataset.jnAvatarFrame = frame;
  if (tier !== "feature") {
    img.classList.add("jn-avatar-frame-chibi-compact");
  }

  let host = img.parentElement;
  if (host?.tagName === "PICTURE") {
    host = host.parentElement;
  }
  if (!host) {
    return;
  }

  host.classList.add(
    "jn-avatar-frame-host",
    "jn-avatar-frame-host-image",
    `jn-avatar-frame-host-chibi-${tier}`
  );

  const overlay = document.createElement("img");
  overlay.className =
    `jn-avatar-frame-overlay jn-avatar-frame-overlay-image jn-avatar-frame-overlay-chibi-${tier}`;
  overlay.dataset.jnAvatarFrameValue = frame;
  overlay.src = frameUrl;
  overlay.alt = "";
  overlay.decoding = "async";
  overlay.setAttribute("aria-hidden", "true");
  host.appendChild(overlay);

  positionImageAvatarFrames();
  if (!img.complete) {
    img.addEventListener("load", positionImageAvatarFrames, { once: true });
  }
}

function avatarImages(root = document) {
  const images = [];
  if (root.matches?.(AVATAR_IMAGE_SELECTOR)) {
    images.push(root);
  }
  root
    .querySelectorAll?.(AVATAR_IMAGE_SELECTOR)
    .forEach((img) => images.push(img));
  return images;
}

function decorateAvatarFrames(root = document) {
  const { username, frame, frameUrl } = activeFrameState;
  if (!username || !frame) {
    return;
  }

  avatarImages(root).forEach((img) => {
    if (!avatarBelongsToUser(img, username)) {
      return;
    }

    if (frame === "neon_aqua") {
      img.classList.add("jn-avatar-frame-neon-aqua");
    } else if (frameUrl) {
      addImageAvatarFrame(img, frame, frameUrl);
    }
  });
}

function applyAvatarFrame(username, frame, frameUrl) {
  activeFrameState = { username, frame, frameUrl };
  clearAvatarFrames();
  document.documentElement.dataset.jnAvatarFrame = frame || "";

  if (!username || !frame) {
    return;
  }

  decorateAvatarFrames();
}

function scheduleAvatarFrameRefresh(root = document) {
  window.clearTimeout(avatarRefreshTimer);
  avatarRefreshTimer = window.setTimeout(() => {
    decorateAvatarFrames(root);
    positionImageAvatarFrames();
  }, 80);
}

function watchForNewAvatars() {
  if (!document.body || window.jnAvatarFrameObserver) {
    return;
  }

  window.jnAvatarFrameObserver = new MutationObserver((mutations) => {
    const avatarAdded = mutations.some((mutation) =>
      [...mutation.addedNodes].some(
        (node) =>
          node.nodeType === Node.ELEMENT_NODE &&
          (node.matches?.(AVATAR_IMAGE_SELECTOR) ||
            node.querySelector?.(AVATAR_IMAGE_SELECTOR))
      )
    );
    if (avatarAdded) {
      scheduleAvatarFrameRefresh(document);
    }
  });
  window.jnAvatarFrameObserver.observe(document.body, {
    childList: true,
    subtree: true,
  });
}

async function refreshCurrentUserCosmetics(api) {
  const username = usernameFromApi(api);
  if (!username) {
    return;
  }

  try {
    const response = await fetch("/points-mall/inventory", {
      credentials: "same-origin",
      headers: { Accept: "application/json" },
    });
    if (!response.ok) {
      return;
    }

    const payload = await response.json();
    const equippedFrame = payload?.inventory?.equipped?.avatar_frame;
    const themeSkin = payload?.inventory?.equipped?.theme_skin?.value;
    applyAvatarFrame(username, equippedFrame?.value, equippedFrame?.image_url);
    applyThemeSkin(themeSkin);
  } catch (_error) {
    // Cosmetic rendering should never block normal forum navigation.
  }
}

export default apiInitializer("1.8.0", (api) => {
  api.addNavigationBarItem({
    name: "points-mall",
    displayName: i18n("points_mall.title"),
    href: "/points-mall",
    classNames: ["points-mall-nav"],
  });

  watchForNewAvatars();
  window.addEventListener("resize", positionImageAvatarFrames);
  refreshCurrentUserCosmetics(api);
  window.addEventListener("jn:cosmetics-updated", (event) => {
    const inventory = event?.detail?.inventory || {};
    const equippedFrame = inventory?.equipped?.avatar_frame;
    applyAvatarFrame(
      usernameFromApi(api),
      equippedFrame?.value,
      equippedFrame?.image_url
    );
    applyThemeSkin(inventory?.equipped?.theme_skin?.value);
  });
  api.onPageChange(() => {
    window.setTimeout(() => refreshCurrentUserCosmetics(api), 150);
  });
});
