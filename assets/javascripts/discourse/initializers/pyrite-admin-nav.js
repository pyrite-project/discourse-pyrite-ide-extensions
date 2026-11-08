import { apiInitializer } from "discourse/lib/api";

export default apiInitializer((api) => {
  if (!api.getCurrentUser()?.staff) {
    return;
  }

  const pluginId = "discourse-pyrite-ide-extensions";
  api.addAdminPluginConfigurationNav(pluginId, [
    {
      label: "pyrite_extensions.admin.title",
      route: "adminPlugins.show.pyrite-registry",
      icon: "puzzle-piece",
    },
  ]);
  api.setAdminPluginIcon(pluginId, "puzzle-piece");
});
