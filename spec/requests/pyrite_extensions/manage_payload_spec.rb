# frozen_string_literal: true

RSpec.describe PyriteExtensions::ExtensionsController, "#show payload" do
  fab!(:author) { Fabricate(:user, trust_level: TrustLevel[1]) }
  fab!(:stranger) { Fabricate(:user, trust_level: TrustLevel[1]) }
  fab!(:admin)
  fab!(:extension) { Fabricate(:pyrite_extension, ext_id: "@my-org/hello", owner: author) }
  fab!(:release) { Fabricate(:pyrite_release, extension:, version: "1.0.0", downloads_count: 7) }

  before { SiteSetting.pyrite_extensions_enabled = true }

  def payload
    get "/pyrite/api/v1/extensions/@my-org/hello"
    response.parsed_body
  end

  it "gives the public view to everyone else" do
    sign_in(stranger)

    expect(payload.keys).not_to include("can_manage", "release_details")
  end

  it "adds download counts and management details for the author" do
    sign_in(author)

    expect(payload).to include("can_manage" => true, "staff" => false)
    expect(payload["release_details"].first).to include("version" => "1.0.0", "downloads_count" => 7)
    expect(payload["withdraw_window_hours"]).to eq(SiteSetting.pyrite_extensions_author_withdraw_window_hours)
  end

  it "marks staff as able to moderate" do
    sign_in(admin)

    expect(payload).to include("can_manage" => true, "staff" => true)
  end

  it "serves the manage and admin page shells" do
    sign_in(author)
    get "/pyrite/manage/@my-org/hello"
    expect(response.status).to eq(200)

    get "/pyrite/admin"
    expect(response.status).to eq(403)

    sign_in(admin)
    get "/pyrite/admin"
    expect(response.status).to eq(200)
  end
end
