import Component from "@glimmer/component";
import { getOwner } from "@ember/owner";
import { action } from "@ember/object";
import { service } from "@ember/service";
import DiscourseURL from "discourse/lib/url";
import DButton from "discourse/ui-kit/d-button";

export default class PyritePublishButton extends Component {
  @service currentUser;
  @service siteSettings;

  get show() {
    const registryId = parseInt(
      this.siteSettings.pyrite_extensions_category,
      10
    );
    if (this.args.outletArgs.category?.id !== registryId) {
      return false;
    }
    if (!this.currentUser) {
      return true;
    }
    return (
      this.currentUser.staff ||
      this.currentUser.trust_level >=
        this.siteSettings.pyrite_extensions_min_trust_level_to_publish
    );
  }

  @action
  publish() {
    if (!this.currentUser) {
      getOwner(this).lookup("route:application").send("showLogin");
      return;
    }
    DiscourseURL.routeTo("/pyrite/new");
  }

  <template>
    {{#if this.show}}
      <DButton
        class="btn-primary pyrite-publish-button"
        @icon="plus"
        @label="pyrite_extensions.publish"
        @action={{this.publish}}
      />
    {{/if}}
  </template>
}
