extends "res://services/content.gd"
## Test/review metadata only; real campaign levels remain the existing three-slot fixture.

var second_region: bool = false
var grouped: bool = false


func region_for_slot(slot: int) -> Dictionary:
	if slot < 1 or slot > slot_count():
		return {}
	var second: bool = second_region and slot == 3
	return {
		"id": "second" if second else "preview",
		"name_key": "journey.preview.region_two" if second else "journey.preview.region",
		"first": 3 if second else 1,
		"last": 2 if second_region and not second else 3
	}


func location_for_slot(slot: int) -> Dictionary:
	if slot < 1 or slot > slot_count():
		return {}
	var id: String = ["harbor", "market", "hill"][slot - 1]
	if grouped:
		id = "harbor" if slot <= 2 else "hill"
	return {
		"id": id,
		"region": "second" if second_region and slot == 3 else "preview",
		"name_key": "journey.preview." + id,
		"first": 1 if grouped and slot <= 2 else slot,
		"last": 2 if grouped and slot <= 2 else slot,
		"postcard": "postcards/" + id + ".webp",
		"pieces": 4
	}
