extends TestCase
## Lines that name the campaign's world come from the campaign (Campaign.realm_name, Campaign.text, QuestRegions'
## `quest_regions`), the first game's words when it gives none.


func after_each() -> void:
	Campaign.use_config(null)


func test_the_first_games_words_by_default() -> void:
	Campaign.use_config({})
	assert_eq(Campaign.realm_name(), "Barovia")
	assert_eq(Campaign.text("respec_option", "Allow rebuilding a character at Madam Eva"), "Allow rebuilding a character at Madam Eva")
	assert_eq(QuestRegions.title("vallaki"), "Vallaki", "the first game's region names")
	assert_true(QuestRegions.rank("death_house") < QuestRegions.rank("castle_ravenloft"))


func test_a_campaigns_own_words() -> void:
	Campaign.use_config({"land_name": "Test Vale", "realm_name": "Test Realm", "texts": {"respec_option": "Allow rebuilding a character"},
		"quest_regions": {"order": ["test_first", "test_second"], "names": {"test_first": "The First Place"}}})
	assert_eq(Campaign.realm_name(), "Test Realm")
	assert_eq(Campaign.path("land_name"), "Test Vale", "the travel map keeps its own land")
	assert_eq(Campaign.text("respec_option", "x"), "Allow rebuilding a character")
	assert_eq(QuestRegions.title("test_first"), "The First Place")
	assert_eq(QuestRegions.title("vallaki"), "Vallaki", "an id it doesn't name is its words, as any unknown id")
	assert_ne(QuestRegions.title("village_of_barovia"), "The Village of Barovia", "never the first game's names once the campaign has its own")
	assert_true(QuestRegions.rank("test_first") < QuestRegions.rank("test_second"))
	assert_eq(QuestRegions.rank("death_house"), 2, "the first game's order is not used either")


func test_realm_falls_back_to_the_land() -> void:
	Campaign.use_config({"land_name": "Test Vale"})
	assert_eq(Campaign.realm_name(), "Test Vale")
