# frozen_string_literal: true

# The package a user uploaded in the first publishing step. Identical files are
# de-duplicated into one Upload, so ownership is also tracked in user_uploads.
class PyriteExtensions::Extension::Action::FindStagedUpload < Service::ActionBase
  option :upload_id
  option :user

  def call
    Upload.where(id: upload_id).find_by(
      "uploads.user_id = :user_id OR EXISTS (SELECT 1 FROM user_uploads WHERE user_uploads.upload_id = uploads.id AND user_uploads.user_id = :user_id)",
      user_id: user.id,
    )
  end
end
