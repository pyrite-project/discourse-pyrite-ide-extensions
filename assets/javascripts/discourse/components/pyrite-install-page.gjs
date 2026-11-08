import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { registerDestructor } from "@ember/destroyable";
import { concat } from "@ember/helper";
import { on } from "@ember/modifier";
import { service } from "@ember/service";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import getURL from "discourse/lib/get-url";
import DButton from "discourse/ui-kit/d-button";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import { i18n } from "discourse-i18n";
import {
  buildDeepLink,
  launchDeepLink,
  packageUrl,
  requiresAcknowledgement,
} from "../lib/pyrite-deep-link";

const LAUNCH_TIMEOUT_MS = 2500;

export default class PyriteInstallPage extends Component {
  @service router;
  @service siteSettings;

  // idle | launching | sent | fallback
  @tracked phase = "idle";

  constructor() {
    super(...arguments);
    registerDestructor(this, () => this.stopWatching());
  }

  get release() {
    return this.args.release;
  }

  get moderation() {
    return this.release.moderation;
  }

  get blocked() {
    return !this.release.installable;
  }

  get needsAcknowledgement() {
    return requiresAcknowledgement(this.moderation);
  }

  get autoLaunch() {
    return !this.blocked && !this.needsAcknowledgement;
  }

  get moderated() {
    return this.moderation.level !== "none";
  }

  get moderationLabel() {
    const label = i18n(`pyrite_extensions.status.${this.moderation.level}`);
    return this.moderation.severity
      ? `${i18n(`pyrite_extensions.severity.${this.moderation.severity}`)} · ${label}`
      : label;
  }

  get origin() {
    return new URL(getURL("/"), window.location.origin).href.replace(/\/$/, "");
  }

  get deepLink() {
    return buildDeepLink({
      extId: this.args.extension.id,
      version: this.release.version,
      origin: this.origin,
    });
  }

  get pyrixUrl() {
    return this.packageLink("pyrix");
  }

  get zipUrl() {
    return this.packageLink("zip");
  }

  get ideDownloadUrl() {
    return this.siteSettings.pyrite_extensions_ide_download_url;
  }

  get statusKey() {
    return {
      launching: "launching",
      sent: "sent",
      fallback: "no_response",
    }[this.phase];
  }

  get canOpen() {
    return !this.blocked;
  }

  get openLabel() {
    return this.phase === "idle"
      ? "pyrite_extensions.install.open_anyway"
      : "pyrite_extensions.install.open_again";
  }

  get fallbackEmphasized() {
    return this.phase === "fallback";
  }

  get versions() {
    return this.args.extension.releases.map((entry) => ({
      version: entry.version,
      selected: entry.version === this.release.version,
    }));
  }

  packageLink(format) {
    return packageUrl({
      origin: this.origin,
      extId: this.args.extension.id,
      version: this.release.version,
      format,
    });
  }

  @action
  begin() {
    if (this.autoLaunch) {
      this.open();
    }
  }

  @action
  open() {
    this.stopWatching();
    this.phase = "launching";
    this.watchForHandoff();
    (this.args.launch ?? launchDeepLink)(this.deepLink);
    this.timer = setTimeout(() => {
      if (this.phase === "launching") {
        this.phase = "fallback";
      }
    }, LAUNCH_TIMEOUT_MS);
  }

  @action
  changeVersion(event) {
    this.router.transitionTo({ queryParams: { version: event.target.value } });
  }

  // Browsers cannot report whether a protocol handler exists; losing focus is the only signal.
  watchForHandoff() {
    this.onHandoff = () => {
      if (this.phase === "launching" || this.phase === "fallback") {
        clearTimeout(this.timer);
        this.phase = "sent";
      }
    };
    this.onVisibility = () => document.hidden && this.onHandoff();
    window.addEventListener("blur", this.onHandoff);
    document.addEventListener("visibilitychange", this.onVisibility);
  }

  stopWatching() {
    clearTimeout(this.timer);
    window.removeEventListener("blur", this.onHandoff);
    document.removeEventListener("visibilitychange", this.onVisibility);
  }

  <template>
    <div class="pyrite-install" {{didInsert this.begin}}>
      <div class="pyrite-install__card">
        <header class="pyrite-install__header">
          <span class="pyrite-install__icon">{{dIcon "puzzle-piece"}}</span>
          <div class="pyrite-install__heading">
            <h1 class="pyrite-install__name">{{@extension.name}}</h1>
            <span class="pyrite-install__byline">
              @{{@extension.owner_username}}
              {{#if @extension.license}}· {{@extension.license}}{{/if}}
            </span>
          </div>
          <select
            class="pyrite-install__version"
            aria-label={{i18n "pyrite_extensions.install.version"}}
            {{on "change" this.changeVersion}}
          >
            {{#each this.versions as |entry|}}
              <option value={{entry.version}} selected={{entry.selected}}>
                v{{entry.version}}
              </option>
            {{/each}}
          </select>
        </header>

        {{#if @release.manifest.permissions.length}}
          <ul class="pyrite-install__permissions">
            {{#each @release.manifest.permissions as |permission|}}
              <li class="pyrite-install__permission">{{permission}}</li>
            {{/each}}
          </ul>
        {{/if}}

        {{#if this.moderated}}
          <div
            class="pyrite-install__banner --{{this.moderation.level}}"
            role="alert"
          >
            <strong>{{this.moderationLabel}}</strong>
            {{#if this.moderation.message}}
              <span>{{this.moderation.message}}</span>
            {{/if}}
          </div>
        {{/if}}

        <div class="pyrite-install__status" role="status" aria-live="polite">
          {{#if this.statusKey}}
            {{i18n (concat "pyrite_extensions.install." this.statusKey)}}
          {{/if}}
        </div>

        {{#if this.canOpen}}
          <div class="pyrite-install__actions">
            <DButton
              class="btn-primary pyrite-install__open"
              @icon="arrow-up-right-from-square"
              @label={{this.openLabel}}
              @action={{this.open}}
            />
          </div>
        {{/if}}

        {{#unless this.blocked}}
          <div
            class="pyrite-install__downloads
              {{if this.fallbackEmphasized '--emphasized'}}"
          >
            <a class="btn btn-default" href={{this.ideDownloadUrl}}>
              {{dIcon "download"}}
              {{i18n "pyrite_extensions.install.download_ide"}}
            </a>
            <a class="btn btn-default" href={{this.pyrixUrl}}>
              {{dIcon "file-zipper"}}
              {{i18n "pyrite_extensions.install.download_pyrix"}}
            </a>
            <a class="btn btn-flat" href={{this.zipUrl}}>
              {{i18n "pyrite_extensions.install.download_zip"}}
            </a>
          </div>
        {{/unless}}

        {{#if @extension.topic_url}}
          <footer class="pyrite-install__footer">
            <a href={{@extension.topic_url}}>
              {{dIcon "arrow-left"}}
              {{i18n "pyrite_extensions.install.back_to_topic"}}
            </a>
          </footer>
        {{/if}}
      </div>
    </div>
  </template>
}
