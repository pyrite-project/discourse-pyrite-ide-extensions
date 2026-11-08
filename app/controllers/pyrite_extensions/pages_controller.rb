# frozen_string_literal: true

module PyriteExtensions
  # Serves the Ember app shell; the pages themselves are client-side routes.
  class PagesController < BaseController
    skip_before_action :check_xhr
    before_action :ensure_logged_in, only: %i[new manage]
    before_action :ensure_staff, only: :admin

    def new
      raise Discourse::InvalidAccess if !guardian.can_publish_pyrite_extension?
      render "default/empty"
    end

    def install
      render "default/empty"
    end

    def manage
      render "default/empty"
    end

    def admin
      render "default/empty"
    end
  end
end
