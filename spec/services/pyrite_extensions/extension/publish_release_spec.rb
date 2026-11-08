# frozen_string_literal: true

require_relative "../../../support/pyrite_package_helper"

RSpec.describe PyriteExtensions::Extension::PublishRelease do
  describe described_class::Contract, type: :model do
    it { is_expected.to validate_presence_of(:ext_id) }
    it { is_expected.to validate_presence_of(:upload_id) }
  end

  describe ".call" do
    subject(:result) { described_class.call(params:, **dependencies) }

    fab!(:author) { Fabricate(:user, trust_level: TrustLevel[1]) }
    fab!(:stranger) { Fabricate(:user, trust_level: TrustLevel[1]) }
    fab!(:admin)
    fab!(:topic, :topic_with_op)
    fab!(:extension) do
      Fabricate(:pyrite_extension, ext_id: "com.example.hello", owner: author, topic:)
    end
    fab!(:existing) { Fabricate(:pyrite_release, extension:, version: "1.0.0") }

    def package_entries(id:, version:)
      { "plugin.toml" => manifest_toml("id" => id, "version" => version), "__main__.py" => "print(1)" }
    end

    let(:manifest_id) { "com.example.hello" }
    let(:manifest_version) { "1.1.0" }
    let(:staged) do
      stage_pyrite_upload(author, package_entries(id: manifest_id, version: manifest_version))
    end
    let(:params) { { ext_id: "com.example.hello", upload_id: staged.id, changelog: "Faster" } }
    let(:dependencies) { { guardian: acting_user.guardian } }
    let(:acting_user) { author }

    before do
      SiteSetting.pyrite_extensions_enabled = true
      extension.update!(latest_release: existing)
    end

    context "when the contract is invalid" do
      let(:params) { { ext_id: "com.example.hello" } }

      it { is_expected.to fail_a_contract }
    end

    context "when the extension does not exist" do
      before { params[:ext_id] = "missing" }

      it { is_expected.to fail_to_find_a_model(:extension) }
    end

    context "when the user does not manage the extension" do
      let(:acting_user) { stranger }

      it { is_expected.to fail_a_policy(:can_manage) }
    end

    context "when the extension was taken down" do
      before { extension.update!(moderation_level: :takedown, moderation_message: "gone") }

      it { is_expected.to fail_a_policy(:extension_not_removed) }
    end

    context "when the upload is not the user's" do
      let(:acting_user) { admin }

      it { is_expected.to fail_to_find_a_model(:upload) }
    end

    context "when the package is invalid" do
      let(:staged) do
        stage_pyrite_upload(author, { "plugin.toml" => "version = ", "__main__.py" => "x" })
      end

      it { is_expected.to fail_a_policy(:valid_package) }
    end

    context "when the package is for another plugin" do
      let(:manifest_id) { "com.example.other" }

      it { is_expected.to fail_a_policy(:package_belongs_to_extension) }
    end

    context "when the version already exists" do
      let(:manifest_version) { "1.0.0" }

      it { is_expected.to fail_a_policy(:version_not_published) }
    end

    context "when the author publishes a new version" do
      it { is_expected.to run_successfully }

      it "creates the release with the package's checksum and the changelog" do
        expect { result }.to change { extension.releases.count }.by(1)

        release = extension.releases.find_by(version: "1.1.0")
        expect(release).to have_attributes(
          changelog: "Faster",
          upload_id: staged.id,
          sha256: Digest::SHA256.file(Discourse.store.path_for(staged)).hexdigest,
        )
      end

      it "makes it the latest release and updates the topic's table" do
        result

        expect(extension.reload.latest_release.version).to eq("1.1.0")
        expect(topic.reload.first_post.raw).to include("1.1.0")
      end
    end

    context "when staff publish on the author's behalf" do
      let(:acting_user) { admin }
      let(:staged) { stage_pyrite_upload(admin, package_entries(id: manifest_id, version: manifest_version)) }

      it { is_expected.to run_successfully }
    end

    context "when staff try to publish inside another user's scope" do
      let(:acting_user) { admin }

      before do
        extension.update!(ext_id: "@author/hello")
        PyriteExtensions::Scope.claim_for(extension.ext_id, author)
        params[:ext_id] = extension.ext_id
      end

      it { is_expected.to fail_a_policy(:scope_available) }
    end

    context "when a backport is published after a higher version" do
      let(:manifest_version) { "0.9.5" }

      it "keeps the highest version as the latest release" do
        result

        expect(extension.reload.latest_release.version).to eq("1.0.0")
        expect(extension.releases.pluck(:version)).to contain_exactly("1.0.0", "0.9.5")
      end
    end

    context "when a pre-release is published" do
      let(:manifest_version) { "2.0.0-rc.1" }

      it "ranks it below the final release of the same version" do
        result
        described_class.call(
          params: {
            ext_id: "com.example.hello",
            upload_id: stage_pyrite_upload(author, package_entries(id: manifest_id, version: "2.0.0")).id,
          },
          guardian: author.guardian,
        )

        expect(extension.reload.latest_release.version).to eq("2.0.0")
      end
    end
  end
end
