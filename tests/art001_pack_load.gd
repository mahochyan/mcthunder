extends SceneTree
## ART-001-R1：临时资源包独立加载测试——仅凭运行时资产
## （GLB + basecolor/normal/orm 三图）重建可渲染材质，不加载主场景/authoring 脚本。
## 证明交付包"只带低模与正式贴图、脱离 authoring 可用"。失败时退出码非 0。

const DIR := "res://assets/art001/m4a3_pilot/"

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var errors: Array[String] = []
	# 1. GLB 独立实例化
	var ps := load(DIR + "m4a3_1k.glb") as PackedScene
	if ps == null:
		errors.append("GLB load failed")
	else:
		var inst: Node = ps.instantiate()
		root.add_child(inst)
		var meshes := 0
		var stack := [inst]
		while not stack.is_empty():
			var n: Node = stack.pop_back()
			if n is MeshInstance3D:
				meshes += 1
			for ch in n.get_children():
				stack.push_back(ch)
		if meshes < 6:
			errors.append("GLB mesh count %d < 6" % meshes)
		# 2. 三图独立加载并组装 ORM 材质（不依赖任何游戏脚本）
		var base := load(DIR + "basecolor.png") as Texture2D
		var nrm := load(DIR + "normal_gl.png") as Texture2D
		var orm := load(DIR + "orm.png") as Texture2D
		if base == null: errors.append("basecolor.png load failed")
		if nrm == null: errors.append("normal_gl.png load failed")
		if orm == null: errors.append("orm.png load failed")
		if base != null and orm != null:
			var mat := StandardMaterial3D.new()
			mat.albedo_texture = base
			mat.normal_enabled = true
			mat.normal_texture = nrm
			mat.roughness_texture = orm
			mat.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_GREEN
			mat.metallic_texture = orm
			mat.metallic_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_BLUE
			mat.ao_texture = orm
			mat.ao_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_RED
			# 3. 材质应用到全部网格（脱离 authoring 的完整装配）
			var applied := 0
			var stack2 := [inst]
			while not stack2.is_empty():
				var n2: Node = stack2.pop_back()
				if n2 is MeshInstance3D:
					(n2 as MeshInstance3D).material_override = mat
					applied += 1
				for ch in n2.get_children():
					stack2.push_back(ch)
			if applied < 6:
				errors.append("material applied to %d < 6 meshes" % applied)
		inst.free()
	# 4. 尺寸校验
	for f in ["basecolor.png", "normal_gl.png", "orm.png"]:
		var t := load(DIR + f) as Texture2D
		if t != null and t.get_width() != 1024:
			errors.append("%s is %dpx, expected 1024" % [f, t.get_width()])
	if errors.is_empty():
		print("ART001_PACK_LOAD PASS: glb+3 textures standalone, material assembled, 1024px OK")
		quit(0)
	else:
		for e in errors:
			print("ART001_PACK_LOAD FAIL: " + e)
		quit(1)