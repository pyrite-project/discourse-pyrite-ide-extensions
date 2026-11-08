# frozen_string_literal: true

require_relative "../../support/pyrite_package_helper"

RSpec.describe "Scoped plugin ids" do
  fab!(:category)
  fab!(:user) { Fabricate(:user, trust_level: TrustLevel[1]) }
  fab!(:extension) { Fabricate(:pyrite_extension, ext_id: "@my-org/hello.plugin", owner: user) }

  let(:upload) { stage_pyrite_upload(user) }
  let!(:release) { Fabricate(:pyrite_release, extension:, version: "1.0.0", upload:) }

  before do
    SiteSetting.pyrite_extensions_enabled = true
    SiteSetting.pyrite_extensions_category = category.id
  end

  it "serves the extension under its scoped id" do
    get "/pyrite/registry/extensions/@my-org/hello.plugin.json"

    expect(response.status).to eq(200)
    expect(response.parsed_body["extension"]).to include("id" => "@my-org/hello.plugin", "latest_version" => nil)
  end

  it "serves a release under its scoped id" do
    get "/pyrite/registry/extensions/@my-org/hello.plugin/releases/1.0.0.json"

    expect(response.status).to eq(200)
    expect(response.parsed_body["release"]).to include("extension_id" => "@my-org/hello.plugin", "version" => "1.0.0")
  end

  it "accepts the scope separator percent-encoded, as npm clients send it" do
    get "/pyrite/registry/extensions/@my-org%2Fhello.plugin/releases/1.0.0.json"

    expect(response.status).to eq(200)
  end

  it "downloads the package with a file name that has no slash" do
    get "/pyrite/registry/extensions/@my-org/hello.plugin/releases/1.0.0/package.pyrix"

    expect(response.status).to eq(200)
    disposition = response.headers["Content-Disposition"]
    expect(disposition).to include("my-org-hello.plugin-1.0.0.pyrix")
    expect(disposition).not_to include("/")
  end

  it "does not confuse a scoped id with the versions path" do
    get "/pyrite/registry/extensions/@my-org/releases/1.0.0.json"

    expect(response.status).to eq(404)
  end

  it "serves the install page shell for a scoped id" do
    get "/pyrite/install/@my-org/hello.plugin"

    expect(response.status).to eq(200)
  end

  it "links the managed block to the scoped install page" do
    extension.update!(latest_release: release)

    block = PyriteExtensions::ManagedBlock.render(extension.reload)

    expect(block).to include("/pyrite/install/@my-org/hello.plugin")
    expect(block).to include("/extensions/@my-org/hello.plugin/releases/1.0.0/package.pyrix")
  end
end
