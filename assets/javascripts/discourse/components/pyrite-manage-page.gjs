import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { ajax } from "discourse/lib/ajax";
import { extractError } from "discourse/lib/ajax-error";
import DButton from "discourse/ui-kit/d-button";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import { i18n } from "discourse-i18n";
import { stagePackage } from "../lib/pyrite-upload";
import PyriteModerationForm from "./pyrite-moderation-form";
import PyriteStatusBadge from "./pyrite-status-badge";

export default class PyriteManagePage extends Component {
  @tracked extension = this.args.extension;
  // { version } while the status form is open; version is null for the package.
  @tracked editing = null;
  @tracked staged = null;
  @tracked changelog = "";
  @tracked uploading = false;
  @tracked publishing = false;
  @tracked error = null;

  get extUrl() {
    return `/pyrite/registry/extensions/${this.extension.id}`;
  }

  get releases() {
    return this.extension.release_details.map((release) => ({
      ...release,
      date: release.published_at?.slice(0, 10),
      sizeKb: Math.max(1, Math.round(release.size / 1024)),
    }));
  }

  get packageLevel() {
    return this.extension.moderation.level;
  }

  get packageFlagged() {
    return this.packageLevel !== "none";
  }

  get wrongPackage() {
    return this.staged && this.staged.manifest.id !== this.extension.id;
  }

  get canPublish() {
    return this.staged && !this.wrongPackage && !this.publishing;
  }

  async refresh() {
    this.extension = (await ajax(`${this.extUrl}.json`)).extension;
  }

  @action
  editPackage() {
    this.editing = { version: null };
  }

  @action
  editRelease(version) {
    this.editing = { version };
  }

  @action
  closeForm() {
    this.editing = null;
  }

  @action
  async statusChanged() {
    this.editing = null;
    await this.refresh();
  }

  @action
  async pick(event) {
    const file = event.target.files[0];
    if (!file) {
      return;
    }
    this.error = null;
    this.staged = null;
    this.uploading = true;
    try {
      this.staged = await stagePackage(file);
    } catch (e) {
      this.error = extractError(e);
    } finally {
      this.uploading = false;
    }
  }

  @action
  setChangelog(event) {
    this.changelog = event.target.value;
  }

  @action
  async publish() {
    this.error = null;
    this.publishing = true;
    try {
      await ajax(`${this.extUrl}/releases.json`, {
        type: "POST",
        data: {
          upload_id: this.staged.upload_id,
          changelog: this.changelog,
        },
      });
      this.staged = null;
      this.changelog = "";
      await this.refresh();
    } catch (e) {
      this.error = extractError(e);
    } finally {
      this.publishing = false;
    }
  }

  <template>
    <div class="pyrite-manage">
      <header class="pyrite-manage__header">
        <h1 class="pyrite-manage__title">{{this.extension.name}}</h1>
        <code class="pyrite-manage__id">{{this.extension.id}}</code>
        {{#if this.extension.topic_url}}
          <a class="pyrite-manage__topic" href={{this.extension.topic_url}}>
            {{dIcon "arrow-left"}}
            {{i18n "pyrite_extensions.manage.back_to_topic"}}
          </a>
        {{/if}}
        {{#if this.extension.staff}}
          <a
            class="pyrite-manage__admin"
            href="/admin/plugins/discourse-pyrite-ide-extensions/registry"
          >
            {{i18n "pyrite_extensions.admin.title"}}
          </a>
        {{/if}}
      </header>

      {{#if this.error}}
        <div class="alert alert-error pyrite-manage__error" role="alert">
          {{this.error}}
        </div>
      {{/if}}

      <section class="pyrite-manage__section">
        <div class="pyrite-manage__section-header">
          <h2>{{i18n "pyrite_extensions.manage.package"}}</h2>
          <PyriteStatusBadge @level={{this.packageLevel}} />
          <DButton
            class="btn-default pyrite-manage__edit-package"
            @label="pyrite_extensions.manage.change_status"
            @action={{this.editPackage}}
          />
        </div>
        {{#if this.packageFlagged}}
          <p class="pyrite-manage__message">
            {{this.extension.moderation.message}}
          </p>
        {{/if}}
      </section>

      <section class="pyrite-manage__section">
        <h2>{{i18n "pyrite_extensions.manage.releases"}}</h2>
        <table class="pyrite-table pyrite-manage__releases">
          <thead>
            <tr>
              <th>{{i18n "pyrite_extensions.manage.version"}}</th>
              <th>{{i18n "pyrite_extensions.manage.published"}}</th>
              <th>{{i18n "pyrite_extensions.manage.downloads"}}</th>
              <th>{{i18n "pyrite_extensions.manage.status"}}</th>
              <th></th>
            </tr>
          </thead>
          <tbody>
            {{#each this.releases as |release|}}
              <tr
                class="pyrite-manage__release"
                data-version={{release.version}}
              >
                <td><code>{{release.version}}</code></td>
                <td>{{release.date}}</td>
                <td>{{release.downloads_count}}</td>
                <td>
                  <PyriteStatusBadge @level={{release.moderation_level}} />
                  {{#if release.moderation_message}}
                    <span class="pyrite-manage__message">
                      {{release.moderation_message}}
                    </span>
                  {{/if}}
                </td>
                <td>
                  <DButton
                    class="btn-flat pyrite-manage__edit-release"
                    @label="pyrite_extensions.manage.change_status"
                    @action={{this.editRelease}}
                    @actionParam={{release.version}}
                  />
                </td>
              </tr>
            {{/each}}
          </tbody>
        </table>
      </section>

      {{#if this.editing}}
        <section class="pyrite-manage__section pyrite-manage__status-form">
          <h2>
            {{#if this.editing.version}}
              {{this.editing.version}}
            {{else}}
              {{i18n "pyrite_extensions.manage.package"}}
            {{/if}}
          </h2>
          <PyriteModerationForm
            @extId={{this.extension.id}}
            @version={{this.editing.version}}
            @staff={{this.extension.staff}}
            @onDone={{this.statusChanged}}
            @onCancel={{this.closeForm}}
          />
        </section>
      {{/if}}

      <section class="pyrite-manage__section pyrite-manage__new-release">
        <h2>{{i18n "pyrite_extensions.manage.new_release"}}</h2>
        <input
          type="file"
          accept=".pyrix,.zip"
          class="pyrite-manage__file"
          {{on "change" this.pick}}
        />
        {{#if this.uploading}}
          <div class="pyrite-manage__status" role="status">
            {{i18n "pyrite_extensions.wizard.checking"}}
          </div>
        {{/if}}
        {{#if this.staged}}
          <dl class="pyrite-wizard__summary">
            <dt>{{i18n "pyrite_extensions.wizard.id"}}</dt>
            <dd>{{this.staged.manifest.id}}</dd>
            <dt>{{i18n "pyrite_extensions.wizard.version"}}</dt>
            <dd>{{this.staged.manifest.version}}</dd>
            <dt>{{i18n "pyrite_extensions.wizard.permissions"}}</dt>
            <dd>
              <ul class="pyrite-chips">
                {{#each this.staged.manifest.permissions as |permission|}}
                  <li class="pyrite-chips__chip">{{permission}}</li>
                {{else}}
                  <li class="pyrite-chips__chip --empty">
                    {{i18n "pyrite_extensions.wizard.none"}}
                  </li>
                {{/each}}
              </ul>
            </dd>
          </dl>
          {{#if this.wrongPackage}}
            <div class="alert alert-error pyrite-manage__wrong-package">
              {{i18n "pyrite_extensions.manage.wrong_package"}}
            </div>
          {{/if}}
          <label class="pyrite-manage__changelog">
            <span>{{i18n "pyrite_extensions.wizard.changelog"}}</span>
            <textarea
              value={{this.changelog}}
              {{on "input" this.setChangelog}}
            ></textarea>
          </label>
          <DButton
            class="btn-primary pyrite-manage__publish"
            @label="pyrite_extensions.wizard.publish"
            @action={{this.publish}}
            @disabled={{if this.canPublish false true}}
            @isLoading={{this.publishing}}
          />
        {{/if}}
      </section>
    </div>
  </template>
}
