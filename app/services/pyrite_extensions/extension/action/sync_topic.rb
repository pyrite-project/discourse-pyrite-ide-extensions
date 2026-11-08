# frozen_string_literal: true

# Brings the extension's topic in line with its registry record: the managed
# block at the top of the first post, and whether the topic is listed at all.
class PyriteExtensions::Extension::Action::SyncTopic < Service::ActionBase
  option :extension

  def call
    topic = extension.topic
    return if topic.nil?

    refresh_managed_block(topic)
    sync_visibility(topic)
  end

  private

  def refresh_managed_block(topic)
    post = topic.first_post
    return if post.nil?

    raw = PyriteExtensions::ManagedBlock.replace_in(post.raw, extension)
    return if raw == post.raw

    post.revise(Discourse.system_user, { raw: }, skip_revision: true, bypass_bump: true)
  end

  def sync_visibility(topic)
    visible = extension.visible_to_public?
    return if topic.visible == visible

    topic.update_status("visible", visible, Discourse.system_user)
  end
end
