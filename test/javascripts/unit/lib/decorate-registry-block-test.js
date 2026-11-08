import { module, test } from "qunit";
import { decorateRegistryBlock } from "discourse/plugins/discourse-pyrite-ide-extensions/discourse/lib/decorate-registry-block";

function cook(html) {
  const element = document.createElement("div");
  element.innerHTML = html;
  return element;
}

const firstPost = { model: { post_number: 1 } };

module("Unit | Utility | decorate-registry-block", function () {
  test("opens the install link in a new tab as a button", function (assert) {
    const element = cook(
      '<p><a href="https://forum.example/pyrite/install/com.example.hello">Open in Pyrite IDE</a></p>'
    );

    decorateRegistryBlock(element, firstPost);

    const link = element.querySelector("a");
    assert.true(link.classList.contains("btn-primary"));
    assert.strictEqual(link.target, "_blank");
    assert.strictEqual(link.rel, "noopener");
  });

  test("leaves other links alone", function (assert) {
    const element = cook('<p><a href="https://example.com">Docs</a></p>');

    decorateRegistryBlock(element, firstPost);

    assert.false(element.querySelector("a").classList.contains("btn"));
  });

  test("turns a callout marker into a styled quote", function (assert) {
    const element = cook(
      "<blockquote><p>[!danger] High advisory: Reads files</p></blockquote>"
    );

    decorateRegistryBlock(element, firstPost);

    const quote = element.querySelector("blockquote");
    assert.true(quote.classList.contains("pyrite-callout"));
    assert.true(quote.classList.contains("--danger"));
    assert.strictEqual(quote.textContent, "High advisory: Reads files");
  });

  test("keeps ordinary quotes untouched", function (assert) {
    const element = cook("<blockquote><p>Someone said so</p></blockquote>");

    decorateRegistryBlock(element, firstPost);

    assert.false(
      element.querySelector("blockquote").classList.contains("pyrite-callout")
    );
  });

  test("only decorates the first post of a topic", function (assert) {
    const element = cook(
      '<p><a href="/pyrite/install/com.example.hello">Open</a></p><blockquote><p>[!note] hi</p></blockquote>'
    );

    decorateRegistryBlock(element, { model: { post_number: 2 } });

    assert.false(element.querySelector("a").classList.contains("btn"));
    assert.false(
      element.querySelector("blockquote").classList.contains("pyrite-callout")
    );
  });
});
