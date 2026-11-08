# frozen_string_literal: true

require_relative "../../support/pyrite_package_helper"

RSpec.describe PyriteExtensions::ReleasesController, "#create" do
  fab!(:author) { Fabricate(:user, trust_level: TrustLevel[1]) }
  fab!(:stranger) { Fabricate(:user, trust_level: TrustLevel[1]) }
  fab!(:topic, :topic_with_op)
  fab!(:extension) { Fabricate(:pyrite_extension, ext_id: "@my-org/hello", owner: author, topic:) }
  fab!(:existing) { Fabricate(:pyrite_release, extension:, version: "1.0.0") }

  let(:url) { "/pyrite/api/v1/extensions/@my-org/hello/versions" }
  let(:version) { "1.1.0" }
  let(:upload) do
    stage_pyrite_upload(
      author,
      {
        "plugin.toml" => manifest_toml("id" => "@my-org/hello", "version" => version),
        "__main__.py" => "print(1)",
      },
    )
  end

  before do
    SiteSetting.pyrite_extensions_enabled = true
    extension.update!(latest_release: existing)
  end

  it "requires signing in" do
    post url, params: { upload_id: upload.id }

    expect(response.status).to eq(403)
  end

  it "publishes a new version of a scoped plugin" do
    sign_in(author)

    post url, params: { upload_id: upload.id, changelog: "Faster" }

    expect(response.status).to eq(200)
    expect(response.parsed_body).to include("version" => "1.1.0")
    expect(extension.reload.latest_release.version).to eq("1.1.0")
  end

  it "makes the new version available to the IDE" do
    sign_in(author)
    post url, params: { upload_id: upload.id }

    get "/pyrite/api/v1/extensions/@my-org/hello/versions/1.1.0"

    expect(response.status).to eq(200)
    expect(response.parsed_body).to include("version" => "1.1.0", "installable" => true)
  end

  it "explains a package that belongs to another plugin" do
    other =
      stage_pyrite_upload(
        author,
        { "plugin.toml" => manifest_toml("id" => "other-plugin", "version" => "1.1.0"), "__main__.py" => "x" },
      )
    sign_in(author)

    post url, params: { upload_id: other.id }

    expect(response.status).to eq(422)
    expect(response.parsed_body["errors"].join).to include("@my-org/hello")
  end

  context "when the version already exists" do
    let(:version) { "1.0.0" }

    it "answers 409" do
      sign_in(author)

      post url, params: { upload_id: upload.id }

      expect(response.status).to eq(409)
    end
  end

  it "forbids someone who can see the plugin but does not manage it" do
    sign_in(stranger)

    post url, params: { upload_id: upload.id }

    expect(response.status).to eq(403)
  end

  it "answers 404 for a removed plugin" do
    extension.update!(moderation_level: :takedown, moderation_message: "gone")
    sign_in(stranger)

    post url, params: { upload_id: upload.id }

    expect(response.status).to eq(404)
  end

  it "answers 404 for an unknown plugin" do
    sign_in(author)

    post "/pyrite/api/v1/extensions/nobody/versions", params: { upload_id: upload.id }

    expect(response.status).to eq(404)
  end
end
