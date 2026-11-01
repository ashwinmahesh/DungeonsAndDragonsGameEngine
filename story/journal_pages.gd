class_name JournalPages
extends RefCounted
## A campaign's own journal pages (data/journal/<page>.json): tabs after the Bestiary that fill in as the story goes (a
## page of the secrets learned and whose they are, a chart of who is what to whom, a clock's warning). A page shows
## while its `when` holds, its entries while theirs do, each entry's text filled from the story (CampaignModule.fill).


## The pages to show now, by `order` then id.
static func shown(st: StoryState) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for p: Variant in Compendium.shared().table("journal").values():
		var page := p as Dictionary
		if StoryConditions.check(str(page.get("when", "")), st):
			out.append(page)
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var oa := int(a.get("order", 0))
		var ob := int(b.get("order", 0))
		return oa < ob if oa != ob else str(a["id"]) < str(b["id"]))
	return out


## The page titled `title` among those shown, or {}.
static func by_title(st: StoryState, title: String) -> Dictionary:
	for page in shown(st):
		if str(page["title"]) == title:
			return page
	return {}


## The page's groups as they stand: [{title, entries: [{title, text}]}], each group with at least one entry shown.
static func groups(page: Dictionary, st: StoryState) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for g: Variant in page.get("groups", []):
		var group := g as Dictionary
		var entries: Array[Dictionary] = []
		for e: Variant in group.get("entries", []):
			var entry := e as Dictionary
			if StoryConditions.check(str(entry.get("when", "")), st):
				entries.append({"title": Campaign.module().fill(str(entry.get("title", "")), st),
					"text": Campaign.module().fill(str(entry.get("text", "")), st)})
		if not entries.is_empty():
			out.append({"title": str(group.get("title", "")), "entries": entries})
	return out


## What the page says while nothing on it is known yet.
static func empty_text(page: Dictionary) -> String:
	return str(page.get("empty", "Nothing here yet."))
