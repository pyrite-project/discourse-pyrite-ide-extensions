# frozen_string_literal: true

module PyriteExtensions
  module Admin
    class ExtensionsController < BaseController
      PAGE_SIZE = 30

      before_action :ensure_staff

      def index
        scope = filtered(Extension.includes(:owner, :releases))
        render_serialized(
          scope.order(updated_at: :desc).offset(page * PAGE_SIZE).limit(PAGE_SIZE).to_a,
          AdminExtensionSerializer,
          root: "extensions",
          meta: { total: scope.count, page_size: PAGE_SIZE },
        )
      end

      def show
        extension = Extension.includes(:owner, :releases, moderation_events: %i[actor release]).find_by(ext_id: params[:ext_id])
        raise Discourse::NotFound if extension.nil?

        render_serialized(extension, AdminExtensionDetailSerializer, root: "extension")
      end

      private

      def page
        [params[:page].to_i, 0].max
      end

      def filtered(scope)
        scope = scope.where("pyrite_extensions.ext_id ILIKE :q OR pyrite_extensions.name ILIKE :q", q: "%#{Extension.sanitize_sql_like(params[:q].to_s)}%") if params[:q].present?
        level = params[:level].presence
        scope = scope.where(moderation_level: Moderatable::LEVELS[level.to_sym]) if level && Moderatable::LEVELS.key?(level.to_sym)
        scope = scope.where.not(moderation_level: 0) if params[:flagged] == "true"
        scope
      end
    end
  end
end
