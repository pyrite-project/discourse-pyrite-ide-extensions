# frozen_string_literal: true

class PyriteExtensions::Extension::SetModeration
  include Service::Base

  LEVELS = PyriteExtensions::Moderatable::LEVELS.keys.map(&:to_s).freeze

  params do
    attribute :ext_id, :string
    attribute :version, :string
    attribute :level, :string
    attribute :severity, :string
    attribute :public_message, :string
    attribute :internal_note, :string

    validates :ext_id, presence: true
    validates :level, inclusion: { in: LEVELS }
    validates :severity, inclusion: { in: PyriteExtensions::Moderatable::SEVERITIES }, if: :advisory?
    validates :public_message, presence: true, unless: :lifting?
    validates :public_message, length: { maximum: 1000 }

    before_validation do
      self.version = version.presence
      self.severity = level == "advisory" ? severity.presence : nil
      self.public_message = public_message.to_s.strip.presence
      self.internal_note = internal_note.to_s.strip.presence
    end

    def advisory?
      level == "advisory"
    end

    def lifting?
      level == "none"
    end
  end

  model :extension
  model :release, optional: true
  policy :release_found
  policy :level_applies_to_scope
  policy :can_set_moderation, class_name: PyriteExtensions::Extension::Policy::CanSetModeration
  policy :takedown_is_final, class_name: PyriteExtensions::Extension::Policy::TakedownIsFinal

  transaction do
    model :target, :apply_moderation
    step :record_event
  end

  only_if :taking_down do
    step :purge_packages
  end
  step :sync_topic

  private

  def fetch_extension(params:)
    PyriteExtensions::Extension.includes(:topic, :releases).find_by(ext_id: params.ext_id)
  end

  def fetch_release(params:, extension:)
    extension.releases.find { |candidate| candidate.version == params.version } if params.version
  end

  def release_found(params:, release:)
    params.version.nil? || release.present?
  end

  # A single release cannot be delisted: that hides a whole package.
  def level_applies_to_scope(params:)
    params.version.nil? || params.level != "delisted"
  end

  def apply_moderation(params:, extension:, release:)
    (release || extension).tap do |target|
      target.update(
        moderation_level: params.level,
        moderation_severity: params.severity,
        moderation_message: params.lifting? ? nil : params.public_message,
      )
    end
  end

  def record_event(params:, extension:, release:, guardian:)
    PyriteExtensions::ModerationEvent.create!(
      extension:,
      release:,
      actor: guardian.user,
      level: params.level,
      severity: params.severity,
      public_message: params.public_message,
      internal_note: params.internal_note,
    )
  end

  def taking_down(params:)
    params.level == "takedown"
  end

  def purge_packages(extension:, release:)
    PyriteExtensions::Extension::Action::PurgePackages.call(extension:, release:)
  end

  def sync_topic(extension:)
    PyriteExtensions::Extension::Action::SyncTopic.call(extension: extension.reload)
  end
end
