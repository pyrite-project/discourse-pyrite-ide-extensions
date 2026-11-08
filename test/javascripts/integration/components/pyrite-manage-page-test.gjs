import { click, fillIn, render, triggerEvent } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import pretender, { response } from "discourse/tests/helpers/create-pretender";
import PyriteManagePage from "discourse/plugins/discourse-pyrite-ide-extensions/discourse/components/pyrite-manage-page";

function buildExtension(overrides = {}) {
  return {
    id: "@my-org/hello",
    name: "Hello",
    topic_url: "/t/hello/1",
    latest_version: "1.1.0",
    releases: [],
    moderation: { level: "none" },
    can_manage: true,
    staff: false,
    release_details: [
      {
        version: "1.1.0",
        published_at: "2026-11-01T10:00:00.000Z",
        downloads_count: 12,
        size: 2048,
        has_package: true,
        moderation_level: "none",
      },
      {
        version: "1.0.0",
        published_at: "2026-10-01T10:00:00.000Z",
        downloads_count: 40,
        size: 2048,
        has_package: true,
        moderation_level: "deprecated",
        moderation_message: "Use 1.1",
      },
    ],
    ...overrides,
  };
}

const staged = (overrides = {}) => ({
  upload_id: 9,
  sha256: "a".repeat(64),
  size: 100,
  existing_extension: true,
  manifest: {
    id: "@my-org/hello",
    version: "1.2.0",
    permissions: ["editor.read"],
  },
  ...overrides,
});

async function chooseFile() {
  await triggerEvent(".pyrite-manage__file", "change", {
    files: [new File(["zip"], "hello.pyrix")],
  });
}

module("Integration | Component | pyrite-manage-page", function (hooks) {
  setupRenderingTest(hooks);

  test("lists releases with downloads and their standing", async function (assert) {
    const extension = buildExtension();
    await render(
      <template><PyriteManagePage @extension={{extension}} /></template>
    );

    assert.dom(".pyrite-manage__title").hasText("Hello");
    assert.dom(".pyrite-manage__id").hasText("@my-org/hello");
    assert.dom(".pyrite-manage__release").exists({ count: 2 });
    assert
      .dom(".pyrite-manage__release[data-version='1.1.0']")
      .includesText("12");
    assert
      .dom(".pyrite-manage__release[data-version='1.0.0']")
      .includesText("Deprecated");
    assert
      .dom(".pyrite-manage__release[data-version='1.0.0']")
      .includesText("Use 1.1");
    assert.dom(".pyrite-manage__topic").hasAttribute("href", "/t/hello/1");
  });

  test("links to the registry admin page for staff only", async function (assert) {
    const author = buildExtension();
    const staff = buildExtension({ staff: true });

    await render(
      <template><PyriteManagePage @extension={{author}} /></template>
    );
    assert.dom(".pyrite-manage__admin").doesNotExist();

    await render(
      <template><PyriteManagePage @extension={{staff}} /></template>
    );
    assert.dom(".pyrite-manage__admin").exists();
  });

  test("opens the status form for one release, then for the package", async function (assert) {
    const extension = buildExtension();
    await render(
      <template><PyriteManagePage @extension={{extension}} /></template>
    );
    assert.dom(".pyrite-manage__status-form").doesNotExist();

    await click(
      ".pyrite-manage__release[data-version='1.1.0'] .pyrite-manage__edit-release"
    );
    assert.dom(".pyrite-manage__status-form h2").hasText("1.1.0");

    await click(".pyrite-manage__edit-package");
    assert.dom(".pyrite-manage__status-form h2").hasText("Package");
  });

  test("publishes a new version and shows it afterwards", async function (assert) {
    let published;
    pretender.post("/pyrite/registry/packages.json", () =>
      response({ package: staged() })
    );
    pretender.post(
      "/pyrite/registry/extensions/@my-org/hello/releases.json",
      (request) => {
        published = new URLSearchParams(request.requestBody);
        return response({ release: { version: "1.2.0" } });
      }
    );
    pretender.get("/pyrite/registry/extensions/@my-org/hello.json", () =>
      response({
        extension: buildExtension({
          release_details: [
            {
              version: "1.2.0",
              published_at: "2026-11-08T10:00:00.000Z",
              downloads_count: 0,
              size: 1,
              has_package: true,
              moderation_level: "none",
            },
            ...buildExtension().release_details,
          ],
        }),
      })
    );
    const extension = buildExtension();
    await render(
      <template><PyriteManagePage @extension={{extension}} /></template>
    );

    await chooseFile();
    assert.dom(".pyrite-wizard__summary").includesText("1.2.0");
    assert.dom(".pyrite-manage__publish").isNotDisabled();

    await fillIn(".pyrite-manage__changelog textarea", "Faster startup");
    await click(".pyrite-manage__publish");

    assert.strictEqual(published.get("upload_id"), "9");
    assert.strictEqual(published.get("changelog"), "Faster startup");
    assert.dom(".pyrite-manage__release").exists({ count: 3 });
    assert.dom(".pyrite-manage__release[data-version='1.2.0']").exists();
    assert.dom(".pyrite-manage__publish").doesNotExist();
  });

  test("refuses a package that belongs to another plugin", async function (assert) {
    pretender.post("/pyrite/registry/packages.json", () =>
      response({
        package: staged({
          manifest: { id: "other-plugin", version: "1.0.0", permissions: [] },
        }),
      })
    );
    const extension = buildExtension();
    await render(
      <template><PyriteManagePage @extension={{extension}} /></template>
    );

    await chooseFile();

    assert.dom(".pyrite-manage__wrong-package").exists();
    assert.dom(".pyrite-manage__publish").isDisabled();
  });

  test("shows why the server rejected a package", async function (assert) {
    pretender.post("/pyrite/registry/packages.json", () =>
      response(422, { errors: ["The package has no __main__.py at its root."] })
    );
    const extension = buildExtension();
    await render(
      <template><PyriteManagePage @extension={{extension}} /></template>
    );

    await chooseFile();

    assert.dom(".pyrite-manage__error").includesText("no __main__.py");
    assert.dom(".pyrite-manage__publish").doesNotExist();
  });

  test("shows the standing of the whole package", async function (assert) {
    const extension = buildExtension({
      moderation: { level: "deprecated", message: "Superseded by Hello 2" },
    });
    await render(
      <template><PyriteManagePage @extension={{extension}} /></template>
    );

    assert.dom(".pyrite-manage__section").includesText("Deprecated");
    assert.dom(".pyrite-manage__section").includesText("Superseded by Hello 2");
  });
});
