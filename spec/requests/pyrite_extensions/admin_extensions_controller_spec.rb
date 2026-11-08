# frozen_string_literal: true

RSpec.describe PyriteExtensions::Admin::ExtensionsController do
  fab!(:admin)
  fab!(:moderator)
  fab!(:user)
  fab!(:one) { Fabricate(:pyrite_extension, ext_id: "alpha-tool", name: "Alpha", owner: user) }
  fab!(:two) do
    Fabricate(:pyrite_extension, ext_id: "@my-org/beta", name: "Beta", owner: user, moderation_level: :deprecated, moderation_message: "old")
  end
  fab!(:release) { Fabricate(:pyrite_release, extension: one, version: "1.0.0") }

  before { SiteSetting.pyrite_extensions_enabled = true }

  def listed(params = {})
    get "/pyrite/registry/admin/extensions.json", params: params
    response.parsed_body["extensions"].map { |extension| extension["id"] }
  end

  it "is closed to everyone but staff" do
    sign_in(user)
    get "/pyrite/registry/admin/extensions.json"
    expect(response.status).to eq(403)

    get "/pyrite/registry/admin/extensions/alpha-tool.json"
    expect(response.status).to eq(403)
  end

  context "when signed in as staff" do
    before { sign_in(moderator) }

    it "lists every package, including ones hidden from the public" do
      two.update!(moderation_level: :takedown)

      expect(listed).to contain_exactly("alpha-tool", "@my-org/beta")
    end

    it "searches by id and by name" do
      expect(listed(q: "beta")).to eq(["@my-org/beta"])
      expect(listed(q: "ALPHA")).to eq(["alpha-tool"])
    end

    it "filters by level and to flagged packages" do
      expect(listed(level: "deprecated")).to eq(["@my-org/beta"])
      expect(listed(flagged: "true")).to eq(["@my-org/beta"])
    end

    it "reports totals for paging" do
      get "/pyrite/registry/admin/extensions.json"

      expect(response.parsed_body["meta"]).to include("total" => 2)
    end

    it "treats a % in the search as text, not a wildcard" do
      expect(listed(q: "%")).to eq([])
    end

    it "shows a package's releases and its audit trail with internal notes" do
      PyriteExtensions::ModerationEvent.create!(
        extension: one,
        release:,
        actor: admin,
        level: "advisory",
        severity: "high",
        public_message: "Reads files",
        internal_note: "Two reports",
      )

      get "/pyrite/registry/admin/extensions/alpha-tool.json"

      expect(response.status).to eq(200)
      body = response.parsed_body["extension"]
      expect(body["releases"].map { |r| r["version"] }).to eq(["1.0.0"])
      expect(body["events"].first).to include(
        "actor_username" => admin.username,
        "version" => "1.0.0",
        "internal_note" => "Two reports",
      )
    end

    it "finds scoped ids and answers 404 for unknown ones" do
      get "/pyrite/registry/admin/extensions/@my-org/beta.json"
      expect(response.status).to eq(200)

      get "/pyrite/registry/admin/extensions/nobody.json"
      expect(response.status).to eq(404)
    end
  end
end
