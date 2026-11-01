extends TestCase
## A campaign's own journal pages (JournalPages, data/journal/): shown while their condition holds, entries while theirs
## do, and the journal shows each as a tab after the Bestiary.

const PAGE := {"id": "test_secrets", "title": "Secrets", "order": 2, "when": "flag.page_open", "empty": "None yet.",
	"groups": [
		{"title": "Townsfolk", "entries": [
			{"when": "flag.secret_a", "title": "The miller", "text": "He cast the hex."},
			{"when": "flag.secret_b", "title": "The innkeeper", "text": "She took the money."}]},
		{"title": "Hidden", "entries": [{"when": "flag.never", "text": "No."}]}]}
const FIRST := {"id": "test_chart", "title": "Chart", "order": 1, "groups": []}

var _saved: Dictionary = {}


func before_each() -> void:
	_saved = Compendium.shared().table("journal").duplicate()
	Compendium.shared().tables["journal"] = {"test_secrets": PAGE, "test_chart": FIRST}


func after_each() -> void:
	Compendium.shared().tables["journal"] = _saved


func test_pages_and_entries_show_as_the_story_reaches_them() -> void:
	var st := StoryState.new()
	assert_eq(JournalPages.shown(st).map(func(p: Dictionary) -> String: return str(p["id"])), ["test_chart"])
	st.flags["page_open"] = true
	assert_eq(JournalPages.shown(st).map(func(p: Dictionary) -> String: return str(p["id"])), ["test_chart", "test_secrets"], "by order")
	assert_true(JournalPages.groups(PAGE, st).is_empty())
	assert_eq(JournalPages.empty_text(PAGE), "None yet.")
	st.flags["secret_b"] = true
	var groups := JournalPages.groups(PAGE, st)
	assert_eq(groups.size(), 1, "a group with nothing shown stays hidden")
	assert_eq(str(groups[0]["title"]), "Townsfolk")
	assert_eq(((groups[0]["entries"] as Array)[0] as Dictionary)["title"], "The innkeeper")


func test_the_journal_shows_a_page_as_a_tab() -> void:
	var st := StoryState.new()
	st.flags["page_open"] = true
	st.flags["secret_a"] = true
	var j := JournalScreen.new()
	add_child(j)
	j.open(self, st, 0)
	assert_eq(j._tabs(), ["Quests", "Codex", "Bestiary", "Chart", "Secrets"] as Array[String])
	j._turn_to("Secrets")
	var found := false
	for l in j.find_children("*", "Label", true, false):
		if (l as Label).text == "He cast the hex.":
			found = true
	assert_true(found, "the entry's text is on the page")
	j.pad_tab(1)
	assert_eq(j.tab, "Quests", "the pages go round")
	j.queue_free()
