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

function clearAvatarFrames() {
  document
    .querySelectorAll("img.jn-avatar-frame-neon-aqua")
    .forEach((node) => node.classList.remove("jn-avatar-frame-neon-aqua"));
  document
    .querySelectorAll(".jn-avatar-frame-overlay")
    .forEach((node) => node.remove());
  document.querySelectorAll(".jn-avatar-frame-host").forEach((node) => {
    node.classList.remove(
      "jn-avatar-frame-host",
      "jn-avatar-frame-host-chibi-blue-heart"
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

function addChibiBlueHeartFrame(img, frameUrl) {
  let host = img.parentElement;
  if (host?.tagName === "PICTURE") {
    host = host.parentElement;
  }
  if (!host) {
    return;
  }

  host.classList.add(
    "jn-avatar-frame-host",
    "jn-avatar-frame-host-chibi-blue-heart"
  );

  const overlay = document.createElement("img");
  overlay.className =
    "jn-avatar-frame-overlay jn-avatar-frame-overlay-chibi-blue-heart";
  overlay.src = frameUrl;
  overlay.alt = "";
  overlay.decoding = "async";
  overlay.setAttribute("aria-hidden", "true");
  host.appendChild(overlay);

  const positionOverlay = () => {
    if (!img.isConnected || !overlay.isConnected) {
      return;
    }

    const imageRect = img.getBoundingClientRect();
    const hostRect = host.getBoundingClientRect();
    const avatarSize = Math.max(imageRect.width, imageRect.height);
    if (!avatarSize) {
      return;
    }

    const frameSize = avatarSize * 1.82;
    overlay.style.width = `${frameSize}px`;
    overlay.style.height = `${frameSize}px`;
    overlay.style.left = `${imageRect.left - hostRect.left + imageRect.width / 2}px`;
    overlay.style.top = `${imageRect.top - hostRect.top + imageRect.height / 2}px`;
  };

  positionOverlay();
  if (!img.complete) {
    img.addEventListener("load", positionOverlay, { once: true });
  }
}

function applyAvatarFrame(username, frame, frameUrl) {
  activeFrameState = { username, frame, frameUrl };
  clearAvatarFrames();
  document.documentElement.dataset.jnAvatarFrame = frame || "";

  if (!username || !["neon_aqua", "chibi_blue_heart"].includes(frame)) {
    return;
  }

  const selectors = [
    ".header-dropdown-toggle.current-user img.avatar",
    ".current-user img.avatar",
    ".user-profile-avatar img.avatar",
    ".user-card-avatar img.avatar",
    "img.avatar",
  ];

  document.querySelectorAll(selectors.join(",")).forEach((img) => {
    if (avatarBelongsToUser(img, username) && frame === "neon_aqua") {
      img.classList.add("jn-avatar-frame-neon-aqua");
    } else if (
      avatarBelongsToUser(img, username) &&
      frame === "chibi_blue_heart" &&
      frameUrl
    ) {
      addChibiBlueHeartFrame(img, frameUrl);
    }
  });
}

function scheduleAvatarFrameRefresh() {
  window.clearTimeout(avatarRefreshTimer);
  avatarRefreshTimer = window.setTimeout(() => {
    applyAvatarFrame(
      activeFrameState.username,
      activeFrameState.frame,
      activeFrameState.frameUrl
    );
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
          (node.matches?.("img.avatar") || node.querySelector?.("img.avatar"))
      )
    );
    if (avatarAdded) {
      scheduleAvatarFrameRefresh();
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
  window.addEventListener("resize", scheduleAvatarFrameRefresh);
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
