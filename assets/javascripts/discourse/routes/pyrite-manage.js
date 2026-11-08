import { ajax } from "discourse/lib/ajax";
import DiscourseURL from "discourse/lib/url";
import DiscourseRoute from "discourse/routes/discourse";

export default class PyriteManageRoute extends DiscourseRoute {
  async model({ ext_id }) {
    const { extension } = await ajax(
      `/pyrite/registry/extensions/${ext_id}.json`
    );
    if (!extension.can_manage) {
      // Visible to everyone, manageable by its author and staff only.
      DiscourseURL.redirectTo(extension.topic_url ?? "/");
    }
    return extension;
  }
}
