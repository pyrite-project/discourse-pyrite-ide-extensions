import { visit } from "@ember/test-helpers";
import { test } from "qunit";
import { acceptance } from "discourse/tests/helpers/qunit-helpers";

const REGISTRY_CATEGORY_ID = 1;

acceptance("Pyrite extensions | Registry category", function (needs) {
  needs.user();
  needs.settings({
    pyrite_extensions_enabled: true,
    pyrite_extensions_category: REGISTRY_CATEGORY_ID,
    pyrite_extensions_min_trust_level_to_publish: 1,
  });

  test("replaces the new topic button with publishing a plugin", async function (assert) {
    await visit(`/c/bug/${REGISTRY_CATEGORY_ID}`);

    assert.dom("#create-topic").doesNotExist();
    assert.dom(".pyrite-publish-button").hasText("Publish plugin");
  });

  test("leaves other categories alone", async function (assert) {
    await visit("/c/feature/2");

    assert.dom("#create-topic").exists();
    assert.dom(".pyrite-publish-button").doesNotExist();
  });
});
