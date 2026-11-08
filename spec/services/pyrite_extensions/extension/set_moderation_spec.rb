# frozen_string_literal: true

require_relative "../../../support/pyrite_package_helper"

RSpec.describe PyriteExtensions::Extension::SetModeration do
  describe described_class::Contract, type: :model do
    it { is_expected.to validate_presence_of(:ext_id) }
    it do
      is_expected.to validate_inclusion_of(:level).in_array(
        PyriteExtensions::Extension::SetModeration::LEVELS,
      )
    end

    it "requires a public reason unless the warning is being lifted" do
      contract = described_class.new(ext_id: "a", level: "deprecated")
      expect(contract).not_to be_valid
      expect(contract.errors[:public_message]).to be_present

      expect(described_class.new(ext_id: "a", level: "none")).to be_valid
    end

    it "requires a severity for advisories only" do
      advisory = described_class.new(ext_id: "a", level: "advisory", public_message: "x")
      expect(advisory).not_to be_valid
      expect(advisory.errors[:severity]).to be_present

      advisory.severity = "high"
      expect(advisory).to be_valid
    end

    it "drops a severity that does not belong to the level" do
      contract =
        described_class.new(
          ext_id: "a",
          level: "deprecated",
          severity: "high",
          public_message: "x",
        )
      contract.valid?

      expect(contract.severity).to be_nil
    end
  end

  describe ".call" do
    subject(:result) { described_class.call(params:, **dependencies) }

    fab!(:admin)
    fab!(:author) { Fabricate(:user, trust_level: TrustLevel[1]) }
    fab!(:stranger) { Fabricate(:user, trust_level: TrustLevel[1]) }
    fab!(:topic, :topic_with_op)
    fab!(:extension) do
      Fabricate(:pyrite_extension, ext_id: "com.example.hello", owner: author, topic:)
    end

    let(:upload) { stage_pyrite_upload(author) }
    let!(:release) do
      Fabricate(:pyrite_release, extension:, version: "1.0.0", upload:, published_at: 1.hour.ago)
    end
    let(:params) do
      { ext_id: "com.example.hello", version:, level:, severity:, public_message:, internal_note: }
    end
    let(:dependencies) { { guardian: acting_user.guardian } }
    let(:acting_user) { admin }
    let(:version) { "1.0.0" }
    let(:level) { "advisory" }
    let(:severity) { "high" }
    let(:public_message) { "Reads files outside the workspace" }
    let(:internal_note) { "Reported by two users" }

    before do
      SiteSetting.pyrite_extensions_enabled = true
      SiteSetting.pyrite_extensions_author_withdraw_window_hours = 72
      extension.update!(latest_release: release)
    end

    context "when the contract is invalid" do
      let(:level) { "scary" }

      it { is_expected.to fail_a_contract }
    end

    context "when the extension does not exist" do
      before { params[:ext_id] = "missing" }

      it { is_expected.to fail_to_find_a_model(:extension) }
    end

    context "when the version does not exist" do
      let(:version) { "9.9.9" }

      it { is_expected.to fail_a_policy(:release_found) }
    end

    context "when delisting a single release" do
      let(:level) { "delisted" }
      let(:severity) { nil }

      it { is_expected.to fail_a_policy(:level_applies_to_scope) }
    end

    context "when the user is neither staff nor the author" do
      let(:acting_user) { stranger }

      it { is_expected.to fail_a_policy(:can_set_moderation) }
    end

    context "when the author sets a level only staff may set" do
      let(:acting_user) { author }

      it { is_expected.to fail_a_policy(:can_set_moderation) }
    end

    context "when the takedown is already in force" do
      before { release.update!(moderation_level: :takedown, moderation_message: "gone") }

      let(:level) { "none" }
      let(:severity) { nil }
      let(:public_message) { nil }

      it { is_expected.to fail_a_policy(:takedown_is_final) }
    end

    context "when staff set an advisory on a release" do
      it { is_expected.to run_successfully }

      it "records the level, severity and public message on the release" do
        result

        expect(release.reload).to have_attributes(
          moderation_level: "advisory",
          moderation_severity: "high",
          moderation_message: public_message,
        )
        expect(extension.reload.moderation_level).to eq("none")
      end

      it "writes an audit event that keeps the internal note" do
        expect { result }.to change { PyriteExtensions::ModerationEvent.count }.by(1)

        event = PyriteExtensions::ModerationEvent.last
        expect(event).to have_attributes(
          actor: admin,
          release:,
          level: "advisory",
          internal_note: "Reported by two users",
        )
      end

      it "shows the advisory in the topic's managed block" do
        result

        expect(topic.reload.first_post.raw).to include("[!danger]", public_message)
      end

      it "keeps the package available" do
        result

        expect(release.reload.upload_id).to be_present
        expect(extension.reload.topic.visible).to eq(true)
      end
    end

    context "when staff warn about the whole package" do
      let(:version) { nil }
      let(:level) { "deprecated" }
      let(:severity) { nil }

      it "applies to the extension and every release through it" do
        result

        expect(extension.reload.moderation_level).to eq("deprecated")
        expect(release.reload.effective_state.level).to eq(:deprecated)
      end
    end

    context "when staff delist the package" do
      let(:version) { nil }
      let(:level) { "delisted" }
      let(:severity) { nil }

      it "unlists the topic and keeps the files" do
        result

        expect(topic.reload.visible).to eq(false)
        expect(release.reload.upload_id).to be_present
      end

      it "lists the topic again when the delisting is lifted" do
        result
        described_class.call(
          params: params.merge(level: "none", public_message: nil),
          guardian: admin.guardian,
        )

        expect(topic.reload.visible).to eq(true)
        expect(extension.reload.moderation_level).to eq("none")
      end
    end

    context "when staff take down one release" do
      let(:level) { "takedown" }
      let(:severity) { nil }

      it "deletes its package and keeps the record" do
        stored = upload
        result

        expect(release.reload.upload_id).to be_nil
        expect(Upload.exists?(stored.id)).to eq(false)
        expect(release.moderation_level).to eq("takedown")
      end
    end

    context "when another release shares the same stored file" do
      let(:level) { "takedown" }
      let(:severity) { nil }
      fab!(:other_extension) { Fabricate(:pyrite_extension, ext_id: "com.example.copy", owner: author) }

      before { Fabricate(:pyrite_release, extension: other_extension, version: "1.0.0", upload:) }

      it "keeps the file for the other release" do
        stored = upload
        result

        expect(release.reload.upload_id).to be_nil
        expect(Upload.exists?(stored.id)).to eq(true)
      end
    end

    context "when staff take down the whole package" do
      let(:version) { nil }
      let(:level) { "takedown" }
      let(:severity) { nil }

      it "deletes every package and hides the topic" do
        result

        expect(release.reload.upload_id).to be_nil
        expect(topic.reload.visible).to eq(false)
        expect(extension.reload.visible_to_public?).to eq(false)
      end
    end

    context "when staff lift a warning" do
      before { release.update!(moderation_level: :advisory, moderation_severity: "low", moderation_message: "old") }

      let(:level) { "none" }
      let(:severity) { nil }
      let(:public_message) { nil }

      it "clears the level, severity and message" do
        result

        expect(release.reload).to have_attributes(
          moderation_level: "none",
          moderation_severity: nil,
          moderation_message: nil,
        )
        expect(topic.reload.first_post.raw).not_to include("[!danger]")
      end
    end

    context "when the author deprecates their own release" do
      let(:acting_user) { author }
      let(:level) { "deprecated" }
      let(:severity) { nil }
      let(:public_message) { "Use Hello 2" }

      it { is_expected.to run_successfully }
    end

    context "when the author withdraws a recent release" do
      let(:acting_user) { author }
      let(:level) { "withdrawn" }
      let(:severity) { nil }
      let(:public_message) { "Published by mistake" }

      it { is_expected.to run_successfully }

      it "stops it from being installed" do
        result

        expect(release.reload.blocks_install?).to eq(true)
      end
    end

    context "when the author withdraws an old release that people downloaded" do
      let(:acting_user) { author }
      let(:level) { "withdrawn" }
      let(:severity) { nil }
      let(:public_message) { "Too late" }

      before { release.update!(published_at: 30.days.ago, downloads_count: 12) }

      it { is_expected.to fail_a_policy(:can_set_moderation) }
    end

    context "when the author tries to lift a staff decision" do
      let(:acting_user) { author }
      let(:level) { "none" }
      let(:severity) { nil }
      let(:public_message) { nil }

      before { release.update!(moderation_level: :advisory, moderation_severity: "high", moderation_message: "x") }

      it { is_expected.to fail_a_policy(:can_set_moderation) }
    end
  end
end
