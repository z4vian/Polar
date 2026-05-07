@tool
extends Sprite2D
## Adds or removes items from an entity inventory.

@export var contents: Array[ContentItem] ## A list of items to be obtained.
@export var use_content_icon := true
@export var icon_display_size := Vector2(24.0, 24.0)

signal contents_got

func _ready() -> void:
	_apply_content_icon()

func _apply_content_icon() -> void:
	if !use_content_icon or contents.size() == 0 or !contents[0].item or !contents[0].item.icon:
		return
	texture = contents[0].item.icon
	region_enabled = false
	hframes = 1
	vframes = 1
	_fit_icon_to_display_size()
	var animation_player := get_node_or_null("AnimationPlayer") as AnimationPlayer
	if animation_player:
		animation_player.stop()

func _fit_icon_to_display_size() -> void:
	if !texture:
		return
	var texture_size := texture.get_size()
	if texture_size.x <= 0.0 or texture_size.y <= 0.0:
		return
	var fit_scale = min(icon_display_size.x / texture_size.x, icon_display_size.y / texture_size.y)
	scale = Vector2.ONE * fit_scale
	_preserve_interaction_area_size()

func _preserve_interaction_area_size() -> void:
	if scale.x == 0.0 or scale.y == 0.0:
		return
	var interaction_area := get_node_or_null("InteractionArea") as Node2D
	if interaction_area:
		interaction_area.scale = Vector2(1.0 / scale.x, 1.0 / scale.y)

func get_contents(params):
	var entity: CharacterEntity = params.get("entity", null)
	if !entity:
		push_warning("Entity is missing in %s" % [get_path()])
		return
	var inventory: Inventory = Globals.get_node_inventory(entity)
	if !inventory:
		push_warning("No inventory found in %s" % [entity.name])
		return
	if contents.size() == 0 or not entity:
		return
	for content in contents:
		if content.quantity > 0:
			inventory.add_item(content.item, content.quantity)
	contents_got.emit.call_deferred()
