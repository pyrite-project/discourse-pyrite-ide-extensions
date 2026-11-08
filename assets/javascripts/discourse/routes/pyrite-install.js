import { ajax } from "discourse/lib/ajax";
import DiscourseRoute from "discourse/routes/discourse";

export default class PyriteInstallRoute extends DiscourseRoute {
  queryParams = { version: { refreshModel: true } };

  async model({ ext_id, version }) {
    const base = `/pyrite/api/v1/extensions/${ext_id}`;
    const extension = await ajax(base);
    const release = await ajax(
      `${base}/versions/${version || extension.latest_version}`
    );
    return { extension, release };
  }
}
