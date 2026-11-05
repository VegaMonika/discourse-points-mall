export const REEL_DURATION = 6600;
export const WINNING_INDEX = 32;

// Continuous deceleration into a short constant-speed glide and a hard stop.
export function reelProgress(t) {
  t = Math.max(0, Math.min(1, t));
  if (t < 0.94) {
    const u = t / 0.94;
    const tangent = 0.2 * 0.94 / 0.988;
    return 0.988 * (1 - Math.pow(1 - u, 3) + tangent * (u * u * u - u * u));
  }
  return 0.988 + 0.2 * (t - 0.94);
}

export function reelGeometry(viewWidth, cardWidth, gap, landing = 0) {
  const start = viewWidth / 2 - cardWidth / 2, step = cardWidth + gap;
  return { start, end: start - WINNING_INDEX * step + landing, step };
}

export function reelFrames(start, end) {
  return Array.from({ length: 201 }, (_, i) => ({ offset: i / 200, transform: `translate3d(${start + (end - start) * reelProgress(i / 200)}px,0,0)` }));
}

export function makeReel(pool, winner, random = Math.random) {
  return Array.from({ length: 40 }, (_, slot) => {
    let item = winner;
    if (slot !== WINNING_INDEX) {
      let value = random() * 100;
      item = pool.find((candidate) => (value -= candidate.probability) < 0) || pool[pool.length - 1];
    }
    return { ...item, slot };
  });
}
