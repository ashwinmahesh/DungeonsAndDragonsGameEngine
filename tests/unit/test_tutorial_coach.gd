extends TestCase
## The tutorial's coaching card (TutorialCoach): a lesson can name its count and keep the card in a corner, so a game's
## own guide reads as one and stays clear of the screen it's guiding.


func test_a_lesson_names_its_count_and_can_keep_the_card_bottom_right() -> void:
	var coach := TutorialCoach.new()
	add_child(coach)
	await get_tree().process_frame
	coach.present({"title": "One", "body": "First.", "objective": "Read it.", "free_practice": true}, 0, 3)
	assert_eq((coach.get("_progress") as Label).text, "LESSON 1 OF 3", "a lesson unless told otherwise")
	coach.present({"title": "Two", "body": "Second.", "objective": "Read it.", "free_practice": true, "progress": "GUIDE",
		"corner": "bottom_right"}, 1, 3)
	await get_tree().process_frame
	assert_eq((coach.get("_progress") as Label).text, "GUIDE 2 OF 3", "named by the lesson")
	var panel := coach.get("_panel") as Control
	var view := coach.get_viewport().get_visible_rect().size
	assert_between(panel.position.x + panel.size.x, view.x - TutorialCoach.MARGIN - 1.0, view.x - TutorialCoach.MARGIN + 1.0, "against the right edge")
	assert_between(panel.position.y + panel.size.y, view.y - TutorialCoach.MARGIN - 1.0, view.y - TutorialCoach.MARGIN + 1.0, "against the bottom")
	coach.free()
