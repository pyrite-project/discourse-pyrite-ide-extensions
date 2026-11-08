import { render } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import pretender, { response } from "discourse/tests/helpers/create-pretender";
import formKit from "discourse/tests/helpers/form-kit-helper";
import PyriteModerationForm from "discourse/plugins/discourse-pyrite-ide-extensions/discourse/components/pyrite-moderation-form";

module("Integration | Component | pyrite-moderation-form", function (hooks) {
  setupRenderingTest(hooks);

  function levelsOffered() {
    return [...document.querySelectorAll("[data-name='level'] option")]
      .map((option) => option.value)
      .filter((value) => value && value !== "__NONE__");
  }

  test("authors can only deprecate or withdraw a release", async function (assert) {
    await render(
      <template>
        <PyriteModerationForm @extId="a" @version="1.0.0" @staff={{false}} />
      </template>
    );

    assert.deepEqual(levelsOffered(), ["none", "deprecated", "withdrawn"]);
    assert.dom("[data-name='internal_note']").doesNotExist();
  });

  test("authors cannot withdraw a whole package", async function (assert) {
    await render(
      <template><PyriteModerationForm @extId="a" @staff={{false}} /></template>
    );

    assert.deepEqual(levelsOffered(), ["none", "deprecated"]);
  });

  test("staff get every level, with delisting only for a whole package", async function (assert) {
    await render(
      <template>
        <PyriteModerationForm @extId="a" @version="1.0.0" @staff={{true}} />
      </template>
    );
    assert.notOk(levelsOffered().includes("delisted"));
    assert.ok(levelsOffered().includes("advisory"));
    assert.ok(levelsOffered().includes("takedown"));
    assert.dom("[data-name='internal_note']").exists();

    await render(
      <template><PyriteModerationForm @extId="a" @staff={{true}} /></template>
    );
    assert.ok(levelsOffered().includes("delisted"));
  });

  test("asks for a severity only for advisories", async function (assert) {
    await render(
      <template>
        <PyriteModerationForm @extId="a" @version="1.0.0" @staff={{true}} />
      </template>
    );
    assert.dom("[data-name='severity']").doesNotExist();

    await formKit().field("level").select("advisory");

    assert.dom("[data-name='severity']").exists();
  });

  test("requires a message to set a warning but not to lift one", async function (assert) {
    let posted = 0;
    pretender.post("/pyrite/registry/extensions/a/moderation.json", () => {
      posted++;
      return response({ success: "OK" });
    });
    await render(
      <template>
        <PyriteModerationForm @extId="a" @version="1.0.0" @staff={{false}} />
      </template>
    );

    await formKit().field("level").select("deprecated");
    await formKit().submit();
    assert.strictEqual(posted, 0);

    await formKit().field("level").select("none");
    await formKit().submit();
    assert.strictEqual(posted, 1);
  });

  test("sends the level, message and version, then reports done", async function (assert) {
    let body;
    let done = 0;
    pretender.post(
      "/pyrite/registry/extensions/%40my-org%2Fa/moderation.json",
      () => response({ success: "OK" })
    );
    pretender.post(
      "/pyrite/registry/extensions/@my-org/a/moderation.json",
      (request) => {
        body = new URLSearchParams(request.requestBody);
        return response({ success: "OK" });
      }
    );
    const onDone = () => done++;
    await render(
      <template>
        <PyriteModerationForm
          @extId="@my-org/a"
          @version="1.0.0"
          @staff={{true}}
          @onDone={{onDone}}
        />
      </template>
    );

    await formKit().field("level").select("advisory");
    await formKit().field("severity").select("high");
    await formKit().field("public_message").fillIn("Reads files");
    await formKit().field("internal_note").fillIn("Two reports");
    await formKit().submit();

    assert.strictEqual(body.get("level"), "advisory");
    assert.strictEqual(body.get("severity"), "high");
    assert.strictEqual(body.get("public_message"), "Reads files");
    assert.strictEqual(body.get("internal_note"), "Two reports");
    assert.strictEqual(body.get("version"), "1.0.0");
    assert.strictEqual(done, 1);
  });
});
