import { ajax } from "discourse/lib/ajax";
import DiscourseRoute from "discourse/routes/discourse";

export default class PyriteInstallRoute extends DiscourseRoute {
  queryParams = { version: { refreshModel: true } };

  async model({ ext_id, version }) {
    const base = `/pyrite/registry/extensions/${ext_id}`;
    const { extension } = await ajax(`${base}.json`);
    const { release } = await ajax(
      `${base}/releases/${version || extension.latest_version}.json`
    );
    return { extension, release };
  }
}
