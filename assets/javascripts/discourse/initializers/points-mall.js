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
let cosmeticsPageTimer;
let cosmeticsRequestState;
const COSMETICS_REFRESH_INTERVAL = 30_000;
const AVATAR_IMAGE_SELECTOR = 'img.avatar, img[src*="/user_avatar/"]';
const AVATAR_FRAME_EXCLUDED_CONTEXT =
  ".modal-container, .d-modal, .dialog-holder, .emoji-picker, .fk-d-menu";

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

function avatarFrameAllowed(img) {
  return !img.closest(AVATAR_FRAME_EXCLUDED_CONTEXT);
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
    if (!avatarFrameAllowed(img) || !avatarBelongsToUser(img, username)) {
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

function cosmeticsStateFor(username) {
  if (cosmeticsRequestState?.username !== username) {
    cosmeticsRequestState = { username, pending: null, nextRefreshAt: 0, revision: 0 };
  }
  return cosmeticsRequestState;
}

function applyCosmeticsInventory(username, inventory) {
  const equippedFrame = inventory?.equipped?.avatar_frame;
  applyAvatarFrame(username, equippedFrame?.value, equippedFrame?.image_url);
  applyThemeSkin(inventory?.equipped?.theme_skin?.value);
}

function refreshCurrentUserCosmetics(api) {
  const username = usernameFromApi(api);
  const state = cosmeticsStateFor(username);
  if (!username) {
    return;
  }

  // Initial rendering and route changes can request the same inventory together.
  // Reuse one request and cool down failed requests as well as successful ones.
  if (state.pending || Date.now() < state.nextRefreshAt) {
    return state.pending;
  }
  state.nextRefreshAt = Date.now() + COSMETICS_REFRESH_INTERVAL;
  const revision = state.revision;
  state.pending = (async () => {
    try {
      const response = await fetch("/points-mall/inventory", {
        credentials: "same-origin",
        headers: { Accept: "application/json" },
      });
      if (!response.ok) {
        return;
      }

      const payload = await response.json();
      // A completed equip/unequip or user change is newer than this request.
      if (
        state !== cosmeticsRequestState ||
        revision !== state.revision ||
        username !== usernameFromApi(api)
      ) {
        return;
      }
      applyCosmeticsInventory(username, payload?.inventory);
    } catch (_error) {
      // Cosmetic rendering should never block normal forum navigation.
    }
  })().finally(() => {
    state.pending = null;
  });
  return state.pending;
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
    const username = usernameFromApi(api);
    const state = cosmeticsStateFor(username);
    state.revision += 1;
    state.nextRefreshAt = Date.now() + COSMETICS_REFRESH_INTERVAL;
    const inventory = event?.detail?.inventory || {};
    applyCosmeticsInventory(username, inventory);
  });
  api.onPageChange(() => {
    window.clearTimeout(cosmeticsPageTimer);
    cosmeticsPageTimer = window.setTimeout(() => refreshCurrentUserCosmetics(api), 150);
  });
});
