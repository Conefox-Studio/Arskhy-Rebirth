extends RefCounted

static func load_tex(path: String) -> Texture2D:
	if ResourceLoader.exists(path):
		var t := load(path) as Texture2D
		if t != null:
			return t
	if FileAccess.file_exists(path):
		var img := Image.load_from_file(path)
		if img != null and not img.is_empty():
			return ImageTexture.create_from_image(img)
	return null


static func exists(path: String) -> bool:
	return ResourceLoader.exists(path) or FileAccess.file_exists(path)
