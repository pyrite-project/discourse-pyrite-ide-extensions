# frozen_string_literal: true

class PyriteExtensions::Extension::Action::CreateTopic < Service::ActionBase
  option :author
  option :title
  option :raw
  option :tags

  def call
    PyriteExtensions::Publishing.allow_topic_creation do
      PostCreator.create!(
        author,
        title:,
        raw:,
        tags:,
        category: SiteSetting.pyrite_extensions_category.to_i,
      ).topic
    end
  end
end
