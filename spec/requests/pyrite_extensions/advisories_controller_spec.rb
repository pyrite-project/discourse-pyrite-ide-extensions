# frozen_string_literal: true

RSpec.describe PyriteExtensions::AdvisoriesController do
  fab!(:user)
  fab!(:extension) { Fabricate(:pyrite_extension, ext_id: "com.example.hello", owner: user) }
  fab!(:scoped) { Fabricate(:pyrite_extension, ext_id: "@my-org/tool", owner: user) }
  fab!(:release) { Fabricate(:pyrite_release, extension:, version: "1.0.0") }
  fab!(:newer) { Fabricate(:pyrite_release, extension:, version: "1.1.0") }
  fab!(:scoped_release) { Fabricate(:pyrite_release, extension: scoped, version: "2.0.0") }

  before do
    SiteSetting.pyrite_extensions_enabled = true
    RateLimiter.enable
  end

  def advisories(releases)
    get "/pyrite/registry/advisories.json", params: { releases: }
    response.parsed_body["advisories"]
  end

  it "reports the standing of each requested release, flagged or not" do
    release.update!(
      moderation_level: :advisory,
      moderation_severity: "high",
      moderation_message: "Reads files",
    )

    result = advisories("com.example.hello@1.0.0,com.example.hello@1.1.0")

    expect(result.map { |entry| entry["version"] }).to contain_exactly("1.0.0", "1.1.0")
    flagged = result.find { |entry| entry["version"] == "1.0.0" }
    expect(flagged).to include("extension_id" => "com.example.hello", "installable" => true)
    expect(flagged["moderation"]).to include(
      "level" => "advisory",
      "severity" => "high",
      "message" => "Reads files",
      "scope" => "release",
    )
    expect(result.find { |entry| entry["version"] == "1.1.0" }["moderation"]["level"]).to eq("none")
  end

  it "splits scoped ids at the last @" do
    result = advisories("@my-org/tool@2.0.0")

    expect(result.map { |entry| [entry["extension_id"], entry["version"]] }).to eq(
      [["@my-org/tool", "2.0.0"]],
    )
  end

  it "inherits a package-wide withdrawal and marks the release as not installable" do
    extension.update!(moderation_level: :takedown, moderation_message: "Malware")

    entry = advisories("com.example.hello@1.0.0").first

    expect(entry["installable"]).to eq(false)
    expect(entry["moderation"]).to include("level" => "takedown", "scope" => "package")
  end

  it "answers for delisted and taken down packages, since the IDE already has them" do
    extension.update!(moderation_level: :delisted)

    expect(advisories("com.example.hello@1.0.0").first["installable"]).to eq(false)
  end

  it "leaves out releases the registry does not know" do
    result = advisories("com.example.hello@9.9.9,nobody@1.0.0")

    expect(result).to eq([])
  end

  it "ignores malformed entries" do
    result = advisories("nonsense,@,@1.0.0,com.example.hello@,com.example.hello@1.0.0")

    expect(result.map { |entry| entry["version"] }).to eq(["1.0.0"])
  end

  it "is readable without signing in" do
    expect(advisories("com.example.hello@1.0.0")).not_to be_empty
    expect(response.status).to eq(200)
  end

  it "refuses requests for too many releases at once" do
    list = (1..101).map { |n| "plugin-#{n}@1.0.0" }.join(",")

    get "/pyrite/registry/advisories.json", params: { releases: list }

    expect(response.status).to eq(400)
  end

  it "rate limits repeated checks from one address" do
    60.times { get "/pyrite/registry/advisories.json", params: { releases: "com.example.hello@1.0.0" } }

    get "/pyrite/registry/advisories.json", params: { releases: "com.example.hello@1.0.0" }

    expect(response.status).to eq(429)
  end
end
