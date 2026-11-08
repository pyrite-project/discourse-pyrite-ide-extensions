# frozen_string_literal: true

RSpec.describe PyriteExtensions::GuardianExtensions do
  fab!(:category)
  fab!(:other_category, :category)
  fab!(:user) { Fabricate(:user, trust_level: TrustLevel[1]) }
  fab!(:admin)
  fab!(:moderator)

  before do
    SiteSetting.pyrite_extensions_enabled = true
    SiteSetting.pyrite_extensions_category = category.id
  end

  describe '#can_create_topic_on_category?' do
    it 'blocks non-staff in the registry category' do
      expect(Guardian.new(user).can_create_topic_on_category?(category)).to eq(false)
    end

    it 'allows staff in the registry category' do
      expect(Guardian.new(admin).can_create_topic_on_category?(category)).to eq(true)
      expect(Guardian.new(moderator).can_create_topic_on_category?(category)).to eq(true)
    end

    it 'allows anyone inside the publishing block, and only there' do
      guardian = Guardian.new(user)

      PyriteExtensions::Publishing.allow_topic_creation do
        expect(guardian.can_create_topic_on_category?(category)).to eq(true)
      end
      expect(guardian.can_create_topic_on_category?(category)).to eq(false)
    end

    it 'restores the previous publishing state when blocks nest or raise' do
      expect { PyriteExtensions::Publishing.allow_topic_creation { raise 'boom' } }.to raise_error(
        'boom'
      )
      expect(PyriteExtensions::Publishing).not_to be_active
    end

    it 'does not affect other categories' do
      expect(Guardian.new(user).can_create_topic_on_category?(other_category)).to eq(true)
    end

    it 'does not restrict the category when the plugin is disabled' do
      SiteSetting.pyrite_extensions_enabled = false

      expect(Guardian.new(user).can_create_topic_on_category?(category)).to eq(true)
    end

    it 'handles a nil category' do
      expect { Guardian.new(user).can_create_topic_on_category?(nil) }.not_to raise_error
    end
  end

  describe '#can_publish_pyrite_extension?' do
    it 'requires the minimum trust level' do
      expect(Guardian.new(user).can_publish_pyrite_extension?).to eq(true)
      expect(
        Guardian.new(Fabricate(:user, trust_level: TrustLevel[0])).can_publish_pyrite_extension?
      ).to eq(false)
    end

    it 'lets staff publish regardless of trust level' do
      staff = Fabricate(:moderator, trust_level: TrustLevel[0])

      expect(Guardian.new(staff).can_publish_pyrite_extension?).to eq(true)
    end

    it 'denies anonymous users' do
      expect(Guardian.new.can_publish_pyrite_extension?).to eq(false)
    end

    it 'denies everyone when the plugin is disabled or no category is configured' do
      SiteSetting.pyrite_extensions_enabled = false
      expect(Guardian.new(admin).can_publish_pyrite_extension?).to eq(false)

      SiteSetting.pyrite_extensions_enabled = true
      SiteSetting.pyrite_extensions_category = ''
      expect(Guardian.new(admin).can_publish_pyrite_extension?).to eq(false)
    end

    it 'follows the configured minimum trust level' do
      SiteSetting.pyrite_extensions_min_trust_level_to_publish = TrustLevel[3]

      expect(Guardian.new(user).can_publish_pyrite_extension?).to eq(false)
    end
  end

  describe '#can_manage_pyrite_extension?' do
    fab!(:extension) { Fabricate(:pyrite_extension, owner: user) }

    it 'allows the owner and staff only' do
      expect(Guardian.new(user).can_manage_pyrite_extension?(extension)).to eq(true)
      expect(Guardian.new(admin).can_manage_pyrite_extension?(extension)).to eq(true)
      expect(Guardian.new(Fabricate(:user)).can_manage_pyrite_extension?(extension)).to eq(false)
      expect(Guardian.new.can_manage_pyrite_extension?(extension)).to eq(false)
    end
  end

  describe '#can_see_pyrite_extension?' do
    fab!(:extension) { Fabricate(:pyrite_extension, owner: user) }
    fab!(:stranger, :user)

    it 'shows public extensions to everyone' do
      expect(Guardian.new.can_see_pyrite_extension?(extension)).to eq(true)
    end

    it 'shows delisted extensions to the owner and staff only' do
      extension.update!(moderation_level: :delisted)

      expect(Guardian.new(user).can_see_pyrite_extension?(extension)).to eq(true)
      expect(Guardian.new(moderator).can_see_pyrite_extension?(extension)).to eq(true)
      expect(Guardian.new(stranger).can_see_pyrite_extension?(extension)).to eq(false)
      expect(Guardian.new.can_see_pyrite_extension?(extension)).to eq(false)
    end

    it 'shows taken down extensions to staff only' do
      extension.update!(moderation_level: :takedown)

      expect(Guardian.new(user).can_see_pyrite_extension?(extension)).to eq(false)
      expect(Guardian.new(admin).can_see_pyrite_extension?(extension)).to eq(true)
    end

    it 'hides extensions that have no topic yet from non-owners' do
      extension.update!(topic: nil)

      expect(Guardian.new(stranger).can_see_pyrite_extension?(extension)).to eq(false)
      expect(Guardian.new(user).can_see_pyrite_extension?(extension)).to eq(true)
    end
  end
end
