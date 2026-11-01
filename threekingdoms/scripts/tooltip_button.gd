extends Button
func _make_custom_tooltip(for_text:String) -> Object:
	var box:=PanelContainer.new();box.mouse_filter=Control.MOUSE_FILTER_IGNORE
	var background:=StyleBoxFlat.new();background.bg_color=Color("101821");background.border_color=Color("c6ad7d");background.set_border_width_all(2);background.set_corner_radius_all(5)
	background.content_margin_left=16;background.content_margin_right=16;background.content_margin_top=12;background.content_margin_bottom=12
	background.shadow_color=Color(0,0,0,.65);background.shadow_size=5
	box.add_theme_stylebox_override("panel",background)
	var rich:=RichTextLabel.new();rich.bbcode_enabled=true;rich.fit_content=true;rich.scroll_active=false;rich.custom_minimum_size=Vector2(430,0);rich.mouse_filter=Control.MOUSE_FILTER_IGNORE
	for font_name in ["normal_font","bold_font","italics_font","bold_italics_font"]:rich.add_theme_font_override(font_name,get_theme_font("font"))
	for size_name in ["normal_font_size","bold_font_size","italics_font_size","bold_italics_font_size"]:rich.add_theme_font_size_override(size_name,17)
	rich.add_theme_constant_override("line_separation",5);rich.add_theme_color_override("default_color",Color("f1f2ec"))
	if has_meta("recipe_bbcode"):rich.text=get_meta("recipe_bbcode")
	else:rich.add_text(for_text)
	box.add_child(rich);return box
