import { click, fillIn, render, triggerEvent } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import pretender, { response } from "discourse/tests/helpers/create-pretender";
import formKit from "discourse/tests/helpers/form-kit-helper";
import PyriteAdminPage from "discourse/plugins/discourse-pyrite-ide-extensions/admin/components/pyrite-admin-page";

const row = (id, overrides = {}) => ({
  id,
  name: id,
  owner_username: "ann",
  moderation_level: "none",
  releases_count: 2,
  flagged_releases_count: 0,
  ...overrides,
});

const detail = {
  id: "@my-org/beta",
  name: "Beta",
  moderation_level: "deprecated",
  moderation_message: "old",
  releases: [
    {
      version: "1.0.0",
      published_at: "2026-10-01T10:00:00.000Z",
      downloads_count: 3,
      moderation_level: "advisory",
    },
  ],
  events: [
    {
      id: 1,
      created_at: "2026-11-02T09:30:00.000Z",
      actor_username: "mod",
      version: "1.0.0",
      level: "advisory",
      public_message: "Reads files",
      internal_note: "Two reports",
    },
  ],
};

module("Integration | Component | pyrite-admin-page", function (hooks) {
  setupRenderingTest(hooks);

  hooks.beforeEach(function () {
    this.requests = [];
    pretender.get("/pyrite/registry/admin/extensions.json", (request) => {
      this.requests.push(request.queryParams);
      return response({
        extensions: [
          row("alpha"),
          row("@my-org/beta", {
            moderation_level: "deprecated",
            flagged_releases_count: 1,
          }),
        ],
        meta: { total: 61, page_size: 30 },
      });
    });
    pretender.get("/pyrite/registry/admin/extensions/@my-org/beta.json", () =>
      response({ extension: detail })
    );
  });

  test("loads and lists every package with its standing", async function (assert) {
    await render(<template><PyriteAdminPage /></template>);

    assert.dom(".pyrite-admin__row").exists({ count: 2 });
    assert
      .dom(".pyrite-admin__row[data-ext-id='@my-org/beta']")
      .includesText("Deprecated");
    assert
      .dom(".pyrite-admin__row[data-ext-id='@my-org/beta']")
      .includesText("(1)");
  });

  test("searches by text", async function (assert) {
    await render(<template><PyriteAdminPage /></template>);

    await fillIn(".pyrite-admin__search", "beta");
    await triggerEvent(".pyrite-admin__toolbar", "submit");

    assert.strictEqual(this.requests.at(-1).q, "beta");
    assert.strictEqual(this.requests.at(-1).page, "0");
  });

  test("filters to flagged packages", async function (assert) {
    await render(<template><PyriteAdminPage /></template>);

    await click(".pyrite-admin__flagged input");

    assert.strictEqual(this.requests.at(-1).flagged, "true");
  });

  test("pages through the list", async function (assert) {
    await render(<template><PyriteAdminPage /></template>);
    assert.dom(".pyrite-admin__previous").isDisabled();
    assert.dom(".pyrite-admin__next").isNotDisabled();

    await click(".pyrite-admin__next");
    assert.strictEqual(this.requests.at(-1).page, "1");
    assert.dom(".pyrite-admin__previous").isNotDisabled();

    await click(".pyrite-admin__next");
    assert.strictEqual(this.requests.at(-1).page, "2");
    assert.dom(".pyrite-admin__next").isDisabled();
  });

  test("shows a package's releases and its history, including internal notes", async function (assert) {
    await render(<template><PyriteAdminPage /></template>);

    await click(".pyrite-admin__row[data-ext-id='@my-org/beta']");

    assert.dom(".pyrite-admin__detail h2").hasText("Beta");
    assert.dom(".pyrite-admin__release").exists({ count: 1 });
    assert.dom(".pyrite-admin__event").includesText("mod");
    assert.dom(".pyrite-admin__event").includesText("Reads files");
    assert.dom(".pyrite-admin__note").hasText("Two reports");
  });

  test("sets a release's status and refreshes both views", async function (assert) {
    let body;
    pretender.post(
      "/pyrite/registry/extensions/@my-org/beta/moderation.json",
      (request) => {
        body = new URLSearchParams(request.requestBody);
        return response({ success: "OK" });
      }
    );
    await render(<template><PyriteAdminPage /></template>);
    await click(".pyrite-admin__row[data-ext-id='@my-org/beta']");
    const listLoads = this.requests.length;

    await click(".pyrite-admin__edit-release");
    await formKit(".pyrite-moderation-form").field("level").select("withdrawn");
    await formKit(".pyrite-moderation-form")
      .field("public_message")
      .fillIn("Broken build");
    await formKit(".pyrite-moderation-form").submit();

    assert.strictEqual(body.get("version"), "1.0.0");
    assert.strictEqual(body.get("level"), "withdrawn");
    assert.strictEqual(body.get("public_message"), "Broken build");
    assert.strictEqual(this.requests.length, listLoads + 1, "the list reloads");
    assert.dom(".pyrite-moderation-form").doesNotExist("the form closes");
  });

  test("sets the status of the whole package, including delisting", async function (assert) {
    let body;
    pretender.post(
      "/pyrite/registry/extensions/@my-org/beta/moderation.json",
      (request) => {
        body = new URLSearchParams(request.requestBody);
        return response({ success: "OK" });
      }
    );
    await render(<template><PyriteAdminPage /></template>);
    await click(".pyrite-admin__row[data-ext-id='@my-org/beta']");

    await click(".pyrite-admin__edit-package");
    await formKit(".pyrite-moderation-form").field("level").select("delisted");
    await formKit(".pyrite-moderation-form")
      .field("public_message")
      .fillIn("Spam");
    await formKit(".pyrite-moderation-form").submit();

    assert.strictEqual(body.get("level"), "delisted");
    assert.notOk(
      body.has("version") && body.get("version"),
      "no version for a package"
    );
  });
});
