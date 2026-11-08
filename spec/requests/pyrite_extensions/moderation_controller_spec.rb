# frozen_string_literal: true

RSpec.describe PyriteExtensions::ModerationController do
  fab!(:admin)
  fab!(:author) { Fabricate(:user, trust_level: TrustLevel[1]) }
  fab!(:stranger) { Fabricate(:user, trust_level: TrustLevel[1]) }
  fab!(:topic, :topic_with_op)
  fab!(:extension) { Fabricate(:pyrite_extension, ext_id: "@my-org/hello", owner: author, topic:) }
  fab!(:release) { Fabricate(:pyrite_release, extension:, version: "1.0.0") }

  let(:url) { "/pyrite/api/v1/extensions/@my-org/hello/moderation" }
  let(:body) { { version: "1.0.0", level: "advisory", severity: "high", public_message: "Reads files" } }

  before do
    SiteSetting.pyrite_extensions_enabled = true
    extension.update!(latest_release: release)
  end

  it "requires signing in" do
    post url, params: body

    expect(response.status).to eq(403)
  end

  it "lets staff flag a release of a scoped plugin" do
    sign_in(admin)

    post url, params: body

    expect(response.status).to eq(200)
    expect(release.reload.moderation_level).to eq("advisory")
  end

  it "reports invalid input as a client error" do
    sign_in(admin)

    post url, params: body.merge(level: "advisory", severity: "")

    expect(response.status).to eq(400)
    expect(response.parsed_body["errors"].join).to match(/severity/i)
  end

  it "refuses to delist a single version" do
    sign_in(admin)

    post url, params: body.merge(level: "delisted", severity: nil)

    expect(response.status).to eq(422)
  end

  it "forbids a signed-in stranger without confirming the plugin exists" do
    sign_in(stranger)

    post url, params: body

    expect(response.status).to eq(403)
    expect(release.reload.moderation_level).to eq("none")
  end

  it "answers 404 for a plugin the user cannot see" do
    extension.update!(moderation_level: :takedown, moderation_message: "gone")
    sign_in(stranger)

    post url, params: body

    expect(response.status).to eq(404)
  end

  it "lets the author deprecate their own plugin" do
    sign_in(author)

    post url, params: { level: "deprecated", public_message: "Use Hello 2" }

    expect(response.status).to eq(200)
    expect(extension.reload.moderation_level).to eq("deprecated")
  end

  it "does not let the author set an advisory" do
    sign_in(author)

    post url, params: body

    expect(response.status).to eq(403)
  end

  it "answers 404 for an unknown version or plugin" do
    sign_in(admin)

    post url, params: body.merge(version: "9.9.9")
    expect(response.status).to eq(404)

    post "/pyrite/api/v1/extensions/nobody/moderation", params: body
    expect(response.status).to eq(404)
  end

  it "makes the new standing visible to the IDE's advisory check" do
    sign_in(admin)
    post url, params: body

    get "/pyrite/api/v1/advisories", params: { releases: "@my-org/hello@1.0.0" }

    entry = response.parsed_body["advisories"].first
    expect(entry["moderation"]).to include("level" => "advisory", "severity" => "high")
  end
end
