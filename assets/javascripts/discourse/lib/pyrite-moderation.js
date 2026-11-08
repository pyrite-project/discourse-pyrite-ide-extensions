export const SEVERITIES = ["low", "moderate", "high", "critical"];

const AUTHOR_LEVELS = ["none", "deprecated", "withdrawn"];
const STAFF_RELEASE_LEVELS = [
  "none",
  "notice",
  "deprecated",
  "advisory",
  "withdrawn",
  "takedown",
];
// Delisting hides a whole package, so a single version cannot be delisted.
const STAFF_PACKAGE_LEVELS = [
  "none",
  "notice",
  "deprecated",
  "advisory",
  "withdrawn",
  "delisted",
  "takedown",
];

// Authors may deprecate their work and withdraw a release; the rest is staff's.
// The server enforces the same rules, this only keeps the form honest.
export function levelsFor({ staff, packageScope }) {
  if (staff) {
    return packageScope ? STAFF_PACKAGE_LEVELS : STAFF_RELEASE_LEVELS;
  }
  return packageScope
    ? AUTHOR_LEVELS.filter((level) => level !== "withdrawn")
    : AUTHOR_LEVELS;
}

export function moderationUrl(extId) {
  return `/pyrite/registry/extensions/${extId}/moderation.json`;
}
