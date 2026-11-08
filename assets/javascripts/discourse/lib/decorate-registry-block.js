const INSTALL_LINK = 'a[href*="/pyrite/install/"]';
const CALLOUT_MARKER = /^\[!(note|warning|danger)\]\s*/;

// The registry-managed block is plain Markdown; this only upgrades how it looks in the browser.
export function decorateRegistryBlock(element, helper) {
  if (helper?.model?.post_number !== 1) {
    return;
  }

  element.querySelectorAll(INSTALL_LINK).forEach((link) => {
    link.classList.add(
      "btn",
      "btn-primary",
      "btn-small",
      "pyrite-install-link"
    );
    link.target = "_blank";
    link.rel = "noopener";
  });

  element.querySelectorAll("blockquote").forEach((quote) => {
    const text = quote.querySelector("p")?.firstChild;
    const marker =
      text?.nodeType === Node.TEXT_NODE && text.data.match(CALLOUT_MARKER);
    if (marker) {
      text.data = text.data.replace(CALLOUT_MARKER, "");
      quote.classList.add("pyrite-callout", `--${marker[1]}`);
    }
  });
}
