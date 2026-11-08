import Component from "@glimmer/component";
import { action } from "@ember/object";
import Form from "discourse/components/form";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { eq } from "discourse/truth-helpers";
import { i18n } from "discourse-i18n";
import { levelsFor, moderationUrl, SEVERITIES } from "../lib/pyrite-moderation";

// Sets the standing of one release (@version) or of the whole package.
export default class PyriteModerationForm extends Component {
  get levelOptions() {
    return levelsFor({
      staff: this.args.staff,
      packageScope: !this.args.version,
    }).map((value) => ({
      value,
      label: i18n(`pyrite_extensions.status.${value}`),
    }));
  }

  get severityOptions() {
    return SEVERITIES.map((value) => ({
      value,
      label: i18n(`pyrite_extensions.severity.${value}`),
    }));
  }

  get initial() {
    return {};
  }

  // Lifting a warning needs no explanation; setting one does.
  @action
  validateMessage(name, value, { data, addError }) {
    if (data.level && data.level !== "none" && !value?.trim()) {
      addError(name, {
        title: i18n("pyrite_extensions.moderation.public_message"),
        message: i18n("pyrite_extensions.moderation.message_required"),
      });
    }
  }

  @action
  async submit(data) {
    try {
      await ajax(moderationUrl(this.args.extId), {
        type: "POST",
        data: { ...data, version: this.args.version },
      });
      this.args.onDone?.();
    } catch (error) {
      popupAjaxError(error);
    }
  }

  <template>
    <Form
      @data={{this.initial}}
      @onSubmit={{this.submit}}
      class="pyrite-moderation-form"
      as |form transientData|
    >
      <form.Field
        @name="level"
        @title={{i18n "pyrite_extensions.moderation.level"}}
        @type="select"
        @validation="required"
        as |field|
      >
        <field.Control as |select|>
          {{#each this.levelOptions as |option|}}
            <select.Option @value={{option.value}}>
              {{option.label}}
            </select.Option>
          {{/each}}
        </field.Control>
      </form.Field>

      {{#if (eq transientData.level "advisory")}}
        <form.Field
          @name="severity"
          @title={{i18n "pyrite_extensions.moderation.severity"}}
          @type="select"
          @validation="required"
          as |field|
        >
          <field.Control as |select|>
            {{#each this.severityOptions as |option|}}
              <select.Option @value={{option.value}}>
                {{option.label}}
              </select.Option>
            {{/each}}
          </field.Control>
        </form.Field>
      {{/if}}

      <form.Field
        @name="public_message"
        @title={{i18n "pyrite_extensions.moderation.public_message"}}
        @type="textarea"
        @validate={{this.validateMessage}}
        as |field|
      >
        <field.Control />
      </form.Field>

      {{#if @staff}}
        <form.Field
          @name="internal_note"
          @title={{i18n "pyrite_extensions.moderation.internal_note"}}
          @type="textarea"
          as |field|
        >
          <field.Control />
        </form.Field>
      {{/if}}

      <form.Actions>
        <form.Button
          @label="pyrite_extensions.moderation.cancel"
          @action={{@onCancel}}
        />
        <form.Submit @label="pyrite_extensions.moderation.apply" />
      </form.Actions>
    </Form>
  </template>
}
