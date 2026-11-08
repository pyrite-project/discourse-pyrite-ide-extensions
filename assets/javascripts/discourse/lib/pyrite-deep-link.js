const SCHEME = "pyride";

export function buildDeepLink({ extId, version, origin }) {
  const query = new URLSearchParams({ id: extId, version, origin });
  return `${SCHEME}://plugin/install?${query}`;
}

export function packageUrl({ origin, extId, version, format }) {
  return `${origin}/pyrite/api/v1/extensions/${extId}/versions/${version}/package.${format}`;
}

// Advisories at these severities must be read and acknowledged before anything is launched.
export function requiresAcknowledgement(moderation) {
  return (
    moderation?.level === "advisory" &&
    ["high", "critical"].includes(moderation.severity)
  );
}

const LAUNCH_FRAME_TTL_MS = 2500;

// Firefox shows an error page when a top-level navigation targets an unhandled scheme,
// so it gets a throwaway iframe instead.
export function launchDeepLink(link) {
  if (/firefox/i.test(navigator.userAgent)) {
    const frame = document.createElement("iframe");
    frame.hidden = true;
    frame.src = link;
    document.body.appendChild(frame);
    setTimeout(() => frame.remove(), LAUNCH_FRAME_TTL_MS);
  } else {
    window.location.href = link;
  }
}
