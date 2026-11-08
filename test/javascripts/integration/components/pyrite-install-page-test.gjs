import { click, render, settled } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import PyriteInstallPage from "discourse/plugins/discourse-pyrite-ide-extensions/discourse/components/pyrite-install-page";

const extension = {
  id: "com.example.hello",
  name: "Hello",
  owner_username: "devon",
  license: "MIT",
  topic_url: "/t/hello/12",
  releases: [{ version: "1.2.0" }, { version: "1.1.0" }],
};

function buildRelease(overrides = {}) {
  return {
    version: "1.2.0",
    manifest: { permissions: ["editor.read"] },
    installable: true,
    moderation: { level: "none" },
    ...overrides,
  };
}

module("Integration | Component | pyrite-install-page", function (hooks) {
  setupRenderingTest(hooks);

  hooks.beforeEach(function () {
    this.launched = [];
    this.launch = (link) => this.launched.push(link);
  });

  test("launches the deep link once and shows the plugin identity", async function (assert) {
    const release = buildRelease();
    const launch = this.launch;

    await render(
      <template>
        <PyriteInstallPage
          @extension={{extension}}
          @release={{release}}
          @launch={{launch}}
        />
      </template>
    );

    assert.strictEqual(this.launched.length, 1);
    assert.true(
      this.launched[0].startsWith(
        "pyride://plugin/install?id=com.example.hello&version=1.2.0&origin="
      )
    );
    assert.dom(".pyrite-install__name").hasText("Hello");
    assert.dom(".pyrite-install__permission").hasText("editor.read");
    assert.dom(".pyrite-install__status").hasText("Opening Pyrite IDE…");
    assert.dom(".pyrite-install__open").hasText("Open again");
  });

  test("reports the hand-off when the page loses focus", async function (assert) {
    const release = buildRelease();
    const launch = this.launch;

    await render(
      <template>
        <PyriteInstallPage
          @extension={{extension}}
          @release={{release}}
          @launch={{launch}}
        />
      </template>
    );
    window.dispatchEvent(new Event("blur"));
    await settled();

    assert.dom(".pyrite-install__status").hasText("Sent to Pyrite IDE");
  });

  test("offers the IDE and package downloads next to the open button", async function (assert) {
    const release = buildRelease();
    const launch = this.launch;

    await render(
      <template>
        <PyriteInstallPage
          @extension={{extension}}
          @release={{release}}
          @launch={{launch}}
        />
      </template>
    );

    assert.dom(".pyrite-install__downloads a[href$='package.pyrix']").exists();
    assert.dom(".pyrite-install__downloads a[href$='package.zip']").exists();
    assert.dom(".pyrite-install__footer a").hasAttribute("href", "/t/hello/12");
  });

  test("waits for a click on high severity advisories", async function (assert) {
    const release = buildRelease({
      moderation: {
        level: "advisory",
        severity: "high",
        message: "Reads files outside the workspace",
      },
    });
    const launch = this.launch;

    await render(
      <template>
        <PyriteInstallPage
          @extension={{extension}}
          @release={{release}}
          @launch={{launch}}
        />
      </template>
    );

    assert.strictEqual(this.launched.length, 0);
    assert.dom(".pyrite-install__banner").includesText("High");
    assert
      .dom(".pyrite-install__banner")
      .includesText("Reads files outside the workspace");
    assert.dom(".pyrite-install__open").hasText("Open anyway");

    await click(".pyrite-install__open");

    assert.strictEqual(this.launched.length, 1);
  });

  test("moderate advisories still launch automatically", async function (assert) {
    const release = buildRelease({
      moderation: { level: "advisory", severity: "moderate", message: "" },
    });
    const launch = this.launch;

    await render(
      <template>
        <PyriteInstallPage
          @extension={{extension}}
          @release={{release}}
          @launch={{launch}}
        />
      </template>
    );

    assert.strictEqual(this.launched.length, 1);
    assert.dom(".pyrite-install__banner").exists();
  });

  test("never launches a release that cannot be installed", async function (assert) {
    const release = buildRelease({
      installable: false,
      moderation: { level: "withdrawn", message: "Superseded by 1.2.1" },
    });
    const launch = this.launch;

    await render(
      <template>
        <PyriteInstallPage
          @extension={{extension}}
          @release={{release}}
          @launch={{launch}}
        />
      </template>
    );

    assert.strictEqual(this.launched.length, 0);
    assert.dom(".pyrite-install__banner").includesText("Withdrawn");
    assert.dom(".pyrite-install__banner").includesText("Superseded by 1.2.1");
    assert.dom(".pyrite-install__open").doesNotExist();
    assert.dom(".pyrite-install__downloads").doesNotExist();
  });
});
