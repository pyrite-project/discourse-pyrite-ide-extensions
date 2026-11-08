import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { fn } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import DButton from "discourse/ui-kit/d-button";
import { i18n } from "discourse-i18n";
import PyriteModerationForm from "./pyrite-moderation-form";
import PyriteStatusBadge from "./pyrite-status-badge";

const BASE = "/pyrite/api/v1/admin/extensions";

// Staff view of every package: search, the audit trail, and setting the
// standing of a package or of one of its releases.
export default class PyriteAdminPage extends Component {
  @tracked extensions = [];
  @tracked total = 0;
  @tracked pageSize = 30;
  @tracked page = 0;
  @tracked query = "";
  @tracked flaggedOnly = false;
  @tracked loading = false;
  @tracked selected = null;
  // { version } while the status form is open; version is null for the package.
  @tracked editing = null;

  get hasPrevious() {
    return this.page > 0;
  }

  get hasNext() {
    return (this.page + 1) * this.pageSize < this.total;
  }

  get empty() {
    return !this.loading && this.extensions.length === 0;
  }

  get releases() {
    return (this.selected?.releases ?? []).map((release) => ({
      ...release,
      date: release.published_at?.slice(0, 10),
    }));
  }

  get events() {
    return (this.selected?.events ?? []).map((event) => ({
      ...event,
      date: event.created_at?.slice(0, 16).replace("T", " "),
    }));
  }

  @action
  load() {
    return this.fetchPage(0);
  }

  async fetchPage(page) {
    this.loading = true;
    try {
      const result = await ajax(BASE, {
        data: {
          q: this.query || undefined,
          flagged: this.flaggedOnly || undefined,
          page,
        },
      });
      this.extensions = result.extensions;
      this.total = result.meta.total;
      this.pageSize = result.meta.page_size;
      this.page = page;
    } catch (error) {
      popupAjaxError(error);
    } finally {
      this.loading = false;
    }
  }

  @action
  setQuery(event) {
    this.query = event.target.value;
  }

  @action
  search(event) {
    event.preventDefault();
    return this.fetchPage(0);
  }

  @action
  toggleFlagged(event) {
    this.flaggedOnly = event.target.checked;
    return this.fetchPage(0);
  }

  @action
  previous() {
    return this.fetchPage(this.page - 1);
  }

  @action
  next() {
    return this.fetchPage(this.page + 1);
  }

  @action
  async select(extId) {
    this.editing = null;
    try {
      this.selected = await ajax(`${BASE}/${extId}`);
    } catch (error) {
      popupAjaxError(error);
    }
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
    const extId = this.selected.ext_id;
    this.editing = null;
    await Promise.all([this.select(extId), this.fetchPage(this.page)]);
  }

  <template>
    <div class="pyrite-admin" {{didInsert this.load}}>
      <h1 class="pyrite-admin__title">
        {{i18n "pyrite_extensions.admin.title"}}
      </h1>

      <form class="pyrite-admin__toolbar" {{on "submit" this.search}}>
        <input
          type="search"
          class="pyrite-admin__search"
          placeholder={{i18n "pyrite_extensions.admin.search"}}
          value={{this.query}}
          {{on "input" this.setQuery}}
        />
        <DButton
          class="btn-default pyrite-admin__search-button"
          @icon="magnifying-glass"
          @action={{this.load}}
        />
        <label class="pyrite-admin__flagged">
          <input
            type="checkbox"
            checked={{this.flaggedOnly}}
            {{on "change" this.toggleFlagged}}
          />
          {{i18n "pyrite_extensions.admin.flagged_only"}}
        </label>
      </form>

      <table class="pyrite-table pyrite-admin__list">
        <thead>
          <tr>
            <th>{{i18n "pyrite_extensions.admin.plugin"}}</th>
            <th>{{i18n "pyrite_extensions.admin.owner"}}</th>
            <th>{{i18n "pyrite_extensions.manage.status"}}</th>
            <th>{{i18n "pyrite_extensions.admin.releases"}}</th>
          </tr>
        </thead>
        <tbody>
          {{#each this.extensions as |extension|}}
            <tr
              class="pyrite-admin__row"
              data-ext-id={{extension.ext_id}}
              {{on "click" (fn this.select extension.ext_id)}}
            >
              <td>
                <strong>{{extension.name}}</strong>
                <code>{{extension.ext_id}}</code>
              </td>
              <td>{{extension.owner_username}}</td>
              <td><PyriteStatusBadge
                  @level={{extension.moderation_level}}
                /></td>
              <td>
                {{extension.releases_count}}
                {{#if extension.flagged_releases_count}}
                  <span class="pyrite-admin__flagged-count">
                    ({{extension.flagged_releases_count}})
                  </span>
                {{/if}}
              </td>
            </tr>
          {{/each}}
        </tbody>
      </table>
      {{#if this.empty}}
        <p class="pyrite-admin__empty">
          {{i18n "pyrite_extensions.admin.no_results"}}
        </p>
      {{/if}}

      <div class="pyrite-admin__pager">
        <DButton
          class="btn-default pyrite-admin__previous"
          @label="pyrite_extensions.admin.previous"
          @action={{this.previous}}
          @disabled={{if this.hasPrevious false true}}
        />
        <DButton
          class="btn-default pyrite-admin__next"
          @label="pyrite_extensions.admin.next"
          @action={{this.next}}
          @disabled={{if this.hasNext false true}}
        />
      </div>

      {{#if this.selected}}
        <section class="pyrite-admin__detail">
          <header class="pyrite-admin__detail-header">
            <h2>{{this.selected.name}}</h2>
            <code>{{this.selected.ext_id}}</code>
            <PyriteStatusBadge @level={{this.selected.moderation_level}} />
            <DButton
              class="btn-default pyrite-admin__edit-package"
              @label="pyrite_extensions.manage.change_status"
              @action={{this.editPackage}}
            />
          </header>
          {{#if this.selected.moderation_message}}
            <p class="pyrite-manage__message">
              {{this.selected.moderation_message}}
            </p>
          {{/if}}

          <table class="pyrite-table pyrite-admin__releases">
            <tbody>
              {{#each this.releases as |release|}}
                <tr
                  class="pyrite-admin__release"
                  data-version={{release.version}}
                >
                  <td><code>{{release.version}}</code></td>
                  <td>{{release.date}}</td>
                  <td>{{release.downloads_count}}</td>
                  <td>
                    <PyriteStatusBadge @level={{release.moderation_level}} />
                  </td>
                  <td>
                    <DButton
                      class="btn-flat pyrite-admin__edit-release"
                      @label="pyrite_extensions.manage.change_status"
                      @action={{this.editRelease}}
                      @actionParam={{release.version}}
                    />
                  </td>
                </tr>
              {{/each}}
            </tbody>
          </table>

          {{#if this.editing}}
            <PyriteModerationForm
              @extId={{this.selected.ext_id}}
              @version={{this.editing.version}}
              @staff={{true}}
              @onDone={{this.statusChanged}}
              @onCancel={{this.closeForm}}
            />
          {{/if}}

          <h3>{{i18n "pyrite_extensions.admin.history"}}</h3>
          <ul class="pyrite-admin__history">
            {{#each this.events as |event|}}
              <li class="pyrite-admin__event">
                <span class="pyrite-admin__event-date">{{event.date}}</span>
                <strong>{{event.actor_username}}</strong>
                <PyriteStatusBadge @level={{event.level}} />
                {{#if event.version}}<code>{{event.version}}</code>{{/if}}
                {{#if event.public_message}}
                  <span>{{event.public_message}}</span>
                {{/if}}
                {{#if event.internal_note}}
                  <em class="pyrite-admin__note">{{event.internal_note}}</em>
                {{/if}}
              </li>
            {{/each}}
          </ul>
        </section>
      {{/if}}
    </div>
  </template>
}
