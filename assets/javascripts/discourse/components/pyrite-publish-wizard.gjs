import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { concat, fn } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { service } from "@ember/service";
import Form from "discourse/components/form";
import { ajax } from "discourse/lib/ajax";
import { extractError } from "discourse/lib/ajax-error";
import DiscourseURL from "discourse/lib/url";
import DButton from "discourse/ui-kit/d-button";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import { i18n } from "discourse-i18n";
import { stagePackage } from "../lib/pyrite-upload";

const STEPS = ["package", "details", "review"];
const SUMMARY_MAX = 280;
const LICENSES = [
  "MIT",
  "Apache-2.0",
  "BSD-3-Clause",
  "BSD-2-Clause",
  "ISC",
  "MPL-2.0",
  "LGPL-3.0-only",
  "GPL-3.0-only",
  "GPL-2.0-only",
  "AGPL-3.0-only",
  "Unlicense",
];

export default class PyritePublishWizard extends Component {
  @service siteSettings;

  @tracked step = "package";
  @tracked staged = null;
  @tracked details = null;
  @tracked error = null;
  @tracked uploading = false;
  @tracked publishing = false;
  @tracked dragging = false;

  licenses = LICENSES;

  get stepIndex() {
    return STEPS.indexOf(this.step);
  }

  get steps() {
    return STEPS.map((id, index) => ({
      id,
      number: index + 1,
      current: id === this.step,
      done: index < this.stepIndex,
    }));
  }

  get onPackageStep() {
    return this.step === "package";
  }

  get onDetailsStep() {
    return this.step === "details";
  }

  get onReviewStep() {
    return this.step === "review";
  }

  get manifest() {
    return this.staged?.manifest;
  }

  get canContinue() {
    return this.staged && !this.staged.existing_extension;
  }

  get categoryId() {
    return parseInt(this.siteSettings.pyrite_extensions_category, 10);
  }

  get initialDetails() {
    return (
      this.details ?? {
        title: this.manifest.name,
        summary: (this.manifest.description ?? "").slice(0, SUMMARY_MAX),
        tags: [],
      }
    );
  }

  get summaryValidation() {
    return `required|length:1,${SUMMARY_MAX}`;
  }

  // Mirrors the server's http(s) check; FormKit's own url rule rejects blank optional fields.
  @action
  validateUrl(name, value, { addError }) {
    if (value && !/^https?:\/\/\S+$/i.test(value)) {
      addError(name, {
        title: i18n(`pyrite_extensions.wizard.${name}`),
        message: i18n("pyrite_extensions.wizard.invalid_url"),
      });
    }
  }

  @action
  preventDefault(event) {
    event.preventDefault();
    this.dragging = true;
  }

  @action
  stopDragging() {
    this.dragging = false;
  }

  @action
  drop(event) {
    event.preventDefault();
    this.dragging = false;
    this.upload(event.dataTransfer.files[0]);
  }

  @action
  pick(event) {
    this.upload(event.target.files[0]);
  }

  async upload(file) {
    if (!file) {
      return;
    }
    this.error = null;
    this.staged = null;
    this.uploading = true;
    try {
      this.staged = await stagePackage(file);
      if (this.staged.existing_extension) {
        this.error = i18n("pyrite_extensions.wizard.already_published");
      }
    } catch (e) {
      this.error = extractError(e);
    } finally {
      this.uploading = false;
    }
  }

  @action
  goTo(step) {
    this.error = null;
    this.step = step;
  }

  @action
  saveDetails(data) {
    this.details = data;
    this.goTo("review");
  }

  @action
  async publish() {
    this.error = null;
    this.publishing = true;
    try {
      const result = await ajax("/pyrite/api/v1/extensions", {
        type: "POST",
        data: { upload_id: this.staged.upload_id, ...this.details },
      });
      DiscourseURL.routeTo(result.topic_url);
    } catch (e) {
      this.error = extractError(e);
      this.publishing = false;
    }
  }

  <template>
    <div class="pyrite-wizard">
      <h1 class="pyrite-wizard__title">
        {{i18n "pyrite_extensions.wizard.title"}}
      </h1>

      <ol class="pyrite-wizard__steps">
        {{#each this.steps as |entry|}}
          <li
            class="pyrite-wizard__step
              {{if entry.current '--current'}}
              {{if entry.done '--done'}}"
            aria-current={{if entry.current "step"}}
          >
            <span class="pyrite-wizard__step-number">{{entry.number}}</span>
            {{i18n (concat "pyrite_extensions.wizard.step_" entry.id)}}
          </li>
        {{/each}}
      </ol>

      {{#if this.error}}
        <div class="alert alert-error pyrite-wizard__error" role="alert">
          {{this.error}}
        </div>
      {{/if}}

      {{#if this.onPackageStep}}
        <div class="pyrite-wizard__panel">
          <label
            class="pyrite-wizard__dropzone {{if this.dragging '--dragging'}}"
            {{on "dragover" this.preventDefault}}
            {{on "dragleave" this.stopDragging}}
            {{on "drop" this.drop}}
          >
            {{dIcon "upload"}}
            <span>{{i18n "pyrite_extensions.wizard.drop_package"}}</span>
            <input
              type="file"
              accept=".pyrix,.zip"
              class="pyrite-wizard__file"
              {{on "change" this.pick}}
            />
          </label>

          {{#if this.uploading}}
            <div class="pyrite-wizard__status" role="status">
              {{i18n "pyrite_extensions.wizard.checking"}}
            </div>
          {{/if}}

          {{#if this.staged}}
            <dl class="pyrite-wizard__summary">
              <dt>{{i18n "pyrite_extensions.wizard.name"}}</dt>
              <dd>{{this.manifest.name}}</dd>
              <dt>{{i18n "pyrite_extensions.wizard.id"}}</dt>
              <dd>{{this.manifest.id}}</dd>
              <dt>{{i18n "pyrite_extensions.wizard.version"}}</dt>
              <dd>{{this.manifest.version}}</dd>
              <dt>{{i18n "pyrite_extensions.wizard.type"}}</dt>
              <dd>{{this.manifest.type}}</dd>
              <dt>{{i18n "pyrite_extensions.wizard.platforms"}}</dt>
              <dd>
                <ul class="pyrite-chips">
                  {{#each this.manifest.platforms as |platform|}}
                    <li class="pyrite-chips__chip">{{platform}}</li>
                  {{/each}}
                </ul>
              </dd>
              <dt>{{i18n "pyrite_extensions.wizard.permissions"}}</dt>
              <dd>
                <ul class="pyrite-chips">
                  {{#each this.manifest.permissions as |permission|}}
                    <li class="pyrite-chips__chip">{{permission}}</li>
                  {{else}}
                    <li class="pyrite-chips__chip --empty">
                      {{i18n "pyrite_extensions.wizard.none"}}
                    </li>
                  {{/each}}
                </ul>
              </dd>
            </dl>
          {{/if}}

          <div class="pyrite-wizard__actions">
            <DButton
              class="btn-primary"
              @label="pyrite_extensions.wizard.next"
              @action={{fn this.goTo "details"}}
              @disabled={{if this.canContinue false true}}
            />
          </div>
        </div>
      {{/if}}

      {{#if this.onDetailsStep}}
        <div class="pyrite-wizard__panel">
          <Form
            @data={{this.initialDetails}}
            @onSubmit={{this.saveDetails}}
            as |form|
          >
            <form.Field
              @name="title"
              @title={{i18n "pyrite_extensions.wizard.topic_title"}}
              @validation="required"
              @type="input"
              as |field|
            >
              <field.Control />
            </form.Field>

            <form.Field
              @name="summary"
              @title={{i18n "pyrite_extensions.wizard.summary"}}
              @validation={{this.summaryValidation}}
              @type="input"
              as |field|
            >
              <field.Control />
            </form.Field>

            <form.Row as |row|>
              <row.Col @size={{6}}>
                <form.Field
                  @name="repo_url"
                  @title={{i18n "pyrite_extensions.wizard.repo_url"}}
                  @validate={{this.validateUrl}}
                  @type="input"
                  as |field|
                >
                  <field.Control />
                </form.Field>
              </row.Col>
              <row.Col @size={{6}}>
                <form.Field
                  @name="homepage_url"
                  @title={{i18n "pyrite_extensions.wizard.homepage_url"}}
                  @validate={{this.validateUrl}}
                  @type="input"
                  as |field|
                >
                  <field.Control />
                </form.Field>
              </row.Col>
            </form.Row>

            <form.Field
              @name="license"
              @title={{i18n "pyrite_extensions.wizard.license"}}
              @type="select"
              as |field|
            >
              <field.Control as |select|>
                {{#each this.licenses as |license|}}
                  <select.Option @value={{license}}>{{license}}</select.Option>
                {{/each}}
              </field.Control>
            </form.Field>

            <form.Field
              @name="tags"
              @title={{i18n "pyrite_extensions.wizard.tags"}}
              @type="tag-chooser"
              as |field|
            >
              <field.Control
                @categoryId={{this.categoryId}}
                @allowCreate={{true}}
              />
            </form.Field>

            <form.Field
              @name="description"
              @title={{i18n "pyrite_extensions.wizard.description"}}
              @type="composer"
              as |field|
            >
              <field.Control @height={{320}} />
            </form.Field>

            <form.Field
              @name="changelog"
              @title={{i18n "pyrite_extensions.wizard.changelog"}}
              @type="textarea"
              as |field|
            >
              <field.Control />
            </form.Field>

            <form.Actions>
              <form.Button
                @label="pyrite_extensions.wizard.back"
                @action={{fn this.goTo "package"}}
              />
              <form.Submit @label="pyrite_extensions.wizard.next" />
            </form.Actions>
          </Form>
        </div>
      {{/if}}

      {{#if this.onReviewStep}}
        <div class="pyrite-wizard__panel">
          <dl class="pyrite-wizard__summary">
            <dt>{{i18n "pyrite_extensions.wizard.topic_title"}}</dt>
            <dd>{{this.details.title}}</dd>
            <dt>{{i18n "pyrite_extensions.wizard.version"}}</dt>
            <dd>{{this.manifest.version}}</dd>
            <dt>{{i18n "pyrite_extensions.wizard.summary"}}</dt>
            <dd>{{this.details.summary}}</dd>
            {{#if this.details.license}}
              <dt>{{i18n "pyrite_extensions.wizard.license"}}</dt>
              <dd>{{this.details.license}}</dd>
            {{/if}}
            <dt>{{i18n "pyrite_extensions.wizard.permissions"}}</dt>
            <dd>
              <ul class="pyrite-chips">
                {{#each this.manifest.permissions as |permission|}}
                  <li class="pyrite-chips__chip">{{permission}}</li>
                {{else}}
                  <li class="pyrite-chips__chip --empty">
                    {{i18n "pyrite_extensions.wizard.none"}}
                  </li>
                {{/each}}
              </ul>
            </dd>
          </dl>

          <div class="pyrite-wizard__actions">
            <DButton
              @label="pyrite_extensions.wizard.back"
              @action={{fn this.goTo "details"}}
            />
            <DButton
              class="btn-primary"
              @label="pyrite_extensions.wizard.publish"
              @action={{this.publish}}
              @isLoading={{this.publishing}}
            />
          </div>
        </div>
      {{/if}}
    </div>
  </template>
}
