# frozen_string_literal: true

module PyriteExtensions
  class Extension < ActiveRecord::Base
    include Moderatable

    self.table_name = 'pyrite_extensions'

    MAX_SUMMARY_LENGTH = 280
    URL_PATTERN = %r{\Ahttps?://[^\s]+\z}

    belongs_to :owner, class_name: 'User'
    belongs_to :topic, optional: true
    belongs_to :latest_release, class_name: 'PyriteExtensions::Release', optional: true
    has_many :releases,
             class_name: 'PyriteExtensions::Release',
             dependent: :destroy,
             inverse_of: :extension
    has_many :moderation_events,
             class_name: 'PyriteExtensions::ModerationEvent',
             dependent: :destroy

    validates :ext_id, presence: true
    validate :ext_id_is_valid
    validates :ext_id,
              uniqueness: {
                message: ->(*) { I18n.t('pyrite_extensions.errors.ext_id_taken_validation') }
              }
    validates :name, presence: true, length: { maximum: Manifest::MAX_NAME_LENGTH }
    validates :summary, length: { maximum: MAX_SUMMARY_LENGTH }
    validates :repo_url, :homepage_url, format: { with: URL_PATTERN }, allow_blank: true

    before_create :claim_scope

    # Semantic version order, not insertion order: a backport 1.0.1 published after 2.0.0 stays below it.
    def releases_newest_first
      releases.sort_by(&:semver).reverse
    end

    def visible_to_public?
      topic_id.present? && !moderation_delisted? && !moderation_takedown?
    end

    private

    def claim_scope
      return if Scope.claim_for(ext_id, owner)

      errors.add(:ext_id, I18n.t('pyrite_extensions.errors.scope_taken'))
      throw :abort
    end

    def ext_id_is_valid
      errors.add(:ext_id, :invalid) if ext_id.present? && !Manifest.valid_id?(ext_id)
    end
  end
end
