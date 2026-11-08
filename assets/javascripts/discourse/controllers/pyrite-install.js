import Controller from "@ember/controller";

export default class PyriteInstallController extends Controller {
  queryParams = ["version"];
  version = null;
}
