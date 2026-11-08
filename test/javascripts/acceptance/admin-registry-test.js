import { currentURL, visit } from "@ember/test-helpers";
import { test } from "qunit";
import PreloadStore from "discourse/lib/preload-store";
import { acceptance } from "discourse/tests/helpers/qunit-helpers";

const PLUGIN_ID = "discourse-pyrite-ide-extensions";
const plugin = {
  id: PLUGIN_ID,
  name: PLUGIN_ID,
  humanized_name: "Pyrite IDE extensions",
  enabled: true,
  admin_route: {
    location: PLUGIN_ID,
    label: "pyrite_extensions.admin.title",
    full_location: "adminPlugins.show",
    use_new_show_route: true,
  },
};

acceptance("Pyrite extensions | Admin registry", function (needs) {
  needs.user({ admin: true, moderator: false, staff: true });
  needs.settings({ pyrite_extensions_enabled: true });

  needs.hooks.beforeEach(() => {
    PreloadStore.store("visiblePlugins", [plugin]);
  });

  needs.pretender((server, helper) => {
    server.get("/admin/plugins", () => helper.response({ plugins: [plugin] }));
    server.get(`/admin/plugins/${PLUGIN_ID}.json`, () =>
      helper.response(plugin)
    );
    server.get("/pyrite/registry/admin/extensions.json", () =>
      helper.response({ extensions: [], meta: { total: 0, page_size: 30 } })
    );
  });

  test("opens the registry in admin and exposes its sidebar entry", async function (assert) {
    await visit(`/admin/plugins/${PLUGIN_ID}`);

    assert.strictEqual(currentURL(), `/admin/plugins/${PLUGIN_ID}/registry`);
    assert.dom(".admin-plugin-config-page .pyrite-admin").exists();
    assert.dom(".pyrite-admin__empty").hasText("No plugins");
    assert
      .dom(`[data-link-name='admin_plugin_${PLUGIN_ID}']`)
      .includesText("Plugin registry");
  });
});
