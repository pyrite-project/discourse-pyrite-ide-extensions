import { apiInitializer } from "discourse/lib/api";
import PyritePublishButton from "../components/pyrite-publish-button";
import { decorateRegistryBlock } from "../lib/decorate-registry-block";

export default apiInitializer((api) => {
  const siteSettings = api.container.lookup("service:site-settings");
  const registryId = parseInt(siteSettings.pyrite_extensions_category, 10);
  if (!siteSettings.pyrite_extensions_enabled || !registryId) {
    return;
  }

  // Topics in the registry category come from the publish flow, so "New topic" gives way to it.
  api.registerValueTransformer(
    "can-create-topic-button",
    ({ value, context }) =>
      context.category?.id === registryId ? false : value
  );
  api.renderInOutlet("after-create-topic-button", PyritePublishButton);
  api.decorateCookedElement(decorateRegistryBlock, { id: "pyrite-extensions" });
});
