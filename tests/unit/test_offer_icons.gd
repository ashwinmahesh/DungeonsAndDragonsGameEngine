extends TestCase
## A trait's offer on the hotbar shows the icon of its own key (Icons.for_action, ActionCatalog's `icon_key`).


func test_an_offer_takes_its_keys_icon() -> void:
	assert_ne(Icons.for_action({"id": "offer:x:some_trait", "icon_key": "memorys_dance"}), null)
	assert_ne(Icons.for_action({"id": "offer:x:other_trait", "icon_key": "reveler_contest"}), null)
	assert_eq(Icons.for_action({"id": "offer:x:other_trait", "icon_key": "memorys_dance"}), Icons.feature("memorys_dance"))
