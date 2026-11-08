import { click, fillIn, render, triggerEvent } from "@ember/test-helpers";
import { module, test } from "qunit";
import sinon from "sinon";
import DiscourseURL from "discourse/lib/url";
import pretender, { response } from "discourse/tests/helpers/create-pretender";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import PyritePublishWizard from "discourse/plugins/discourse-pyrite-ide-extensions/discourse/components/pyrite-publish-wizard";

const manifest = {
  id: "com.example.hello",
  name: "Hello",
  version: "1.2.0",
  type: "ui",
  description: "Says hello",
  platforms: ["windows", "macos"],
  permissions: ["editor.read"],
};

function stagedPackage(overrides = {}) {
  return {
    upload_id: 7,
    sha256: "a".repeat(64),
    size: 123,
    existing_extension: false,
    manifest,
    ...overrides,
  };
}

async function chooseFile() {
  await triggerEvent(".pyrite-wizard__file", "change", {
    files: [new File(["zip"], "hello.pyrix")],
  });
}

module("Integration | Component | pyrite-publish-wizard", function (hooks) {
  setupRenderingTest(hooks);

  hooks.beforeEach(function () {
    this.siteSettings.pyrite_extensions_category = 5;
    pretender.get("/tags/filter/search", () => response({ results: [] }));
  });

  test("starts on the package step with nothing to continue with", async function (assert) {
    await render(<template><PyritePublishWizard /></template>);

    assert.dom(".pyrite-wizard__step.--current").includesText("Package");
    assert.dom(".pyrite-wizard__actions .btn-primary").isDisabled();
  });

  test("shows what the server found in the uploaded package", async function (assert) {
    pretender.post("/pyrite/api/v1/packages", () => response(stagedPackage()));

    await render(<template><PyritePublishWizard /></template>);
    await chooseFile();

    assert.dom(".pyrite-wizard__summary").includesText("Hello");
    assert.dom(".pyrite-wizard__summary").includesText("com.example.hello");
    assert.dom(".pyrite-wizard__summary").includesText("1.2.0");
    assert.dom(".pyrite-wizard__summary").includesText("editor.read");
    assert.dom(".pyrite-wizard__actions .btn-primary").isNotDisabled();
  });

  test("shows the server's reason when the package is rejected", async function (assert) {
    pretender.post("/pyrite/api/v1/packages", () =>
      response(422, { errors: ["The package has no __main__.py at its root."] })
    );

    await render(<template><PyritePublishWizard /></template>);
    await chooseFile();

    assert.dom(".pyrite-wizard__error").includesText("no __main__.py");
    assert.dom(".pyrite-wizard__summary").doesNotExist();
    assert.dom(".pyrite-wizard__actions .btn-primary").isDisabled();
  });

  test("refuses to continue with a plugin that is already published", async function (assert) {
    pretender.post("/pyrite/api/v1/packages", () =>
      response(stagedPackage({ existing_extension: true }))
    );

    await render(<template><PyritePublishWizard /></template>);
    await chooseFile();

    assert.dom(".pyrite-wizard__error").includesText("already published");
    assert.dom(".pyrite-wizard__actions .btn-primary").isDisabled();
  });

  test("walks from the package to a published topic", async function (assert) {
    let published;
    pretender.post("/pyrite/api/v1/packages", () => response(stagedPackage()));
    pretender.post("/pyrite/api/v1/extensions", (request) => {
      published = new URLSearchParams(request.requestBody);
      return response({
        success: "OK",
        ext_id: "com.example.hello",
        topic_url: "/t/hello/12",
      });
    });
    const routeTo = sinon.stub(DiscourseURL, "routeTo");

    await render(<template><PyritePublishWizard /></template>);
    await chooseFile();
    await click(".pyrite-wizard__actions .btn-primary");

    assert.dom(".pyrite-wizard__step.--current").includesText("Details");
    assert.dom("[data-name='title'] input").hasValue("Hello");
    assert.dom("[data-name='summary'] input").hasValue("Says hello");

    await fillIn("[data-name='summary'] input", "A friendly greeter");
    await click(".pyrite-wizard form .btn-primary");

    assert.dom(".pyrite-wizard__step.--current").includesText("Review");
    assert.dom(".pyrite-wizard__summary").includesText("A friendly greeter");

    await click(".pyrite-wizard__actions .btn-primary");

    assert.strictEqual(published.get("upload_id"), "7");
    assert.strictEqual(published.get("title"), "Hello");
    assert.strictEqual(published.get("summary"), "A friendly greeter");
    assert.true(routeTo.calledWith("/t/hello/12"));
  });

  test("keeps the entered details when going back from the review step", async function (assert) {
    pretender.post("/pyrite/api/v1/packages", () => response(stagedPackage()));

    await render(<template><PyritePublishWizard /></template>);
    await chooseFile();
    await click(".pyrite-wizard__actions .btn-primary");
    await fillIn("[data-name='summary'] input", "Changed summary");
    await click(".pyrite-wizard form .btn-primary");
    await click(".pyrite-wizard__actions .btn:not(.btn-primary)");

    assert.dom(".pyrite-wizard__step.--current").includesText("Details");
    assert.dom("[data-name='summary'] input").hasValue("Changed summary");
  });
});
