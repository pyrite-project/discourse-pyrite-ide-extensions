# frozen_string_literal: true

module PyriteExtensions
  class ModerationController < BaseController
    before_action :ensure_logged_in

    def create
      Extension::SetModeration.call(service_params) do
        on_success { render json: success_json }
        on_failed_contract { |contract| render_json_error(contract.errors.full_messages, status: 400) }
        on_model_not_found(:extension) { raise Discourse::NotFound }
        on_failed_policy(:release_found) { raise Discourse::NotFound }
        on_failed_policy(:level_applies_to_scope) do
          render_json_error(I18n.t("pyrite_extensions.errors.delist_whole_package"), status: 422)
        end
        # Someone who cannot even see the plugin must not learn that it exists.
        on_failed_policy(:can_set_moderation) do |_policy, extension:|
          raise(guardian.can_see_pyrite_extension?(extension) ? Discourse::InvalidAccess : Discourse::NotFound)
        end
        on_failed_policy(:takedown_is_final) { |policy| render_json_error(policy.reason, status: 422) }
        on_model_errors(:target) { |target| render_json_error(target, status: 422) }
      end
    end
  end
end
