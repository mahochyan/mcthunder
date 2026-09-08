class_name ShotRecordCodec
extends RefCounted
const MAX_BYTES := 2*1024*1024
const MAX_DEPTH := 32
const MAX_VALUES := 160000

static func encode(record: Dictionary) -> Dictionary:
	var errors: Array[String] = []
	var count := [0]
	var value: Variant = _encode_value(record,0,count,errors)
	if not errors.is_empty(): return {"ok":false,"reason":errors[0]}
	var json := JSON.stringify(value,"  ",true,true)
	if json.to_utf8_buffer().size()>MAX_BYTES: return {"ok":false,"reason":"record_size_limit"}
	return {"ok":true,"json":json}

static func decode(json: String) -> Dictionary:
	if json.to_utf8_buffer().size()>MAX_BYTES: return {"ok":false,"reason":"record_size_limit"}
	var parser := JSON.new()
	if parser.parse(json) != OK: return {"ok":false,"reason":"invalid_json"}
	var errors: Array[String] = []
	var count := [0]
	var record: Variant = _decode_value(parser.data,0,count,errors)
	if not errors.is_empty(): return {"ok":false,"reason":errors[0]}
	if not record is Dictionary: return {"ok":false,"reason":"record_not_object"}
	var valid := ShotRecordBuilder.validate(record)
	if not valid.ok: return valid
	return {"ok":true,"record":record}

static func _within_budget(depth: int, count: Array, errors: Array[String]) -> bool:
	count[0] += 1
	if depth>MAX_DEPTH or count[0]>MAX_VALUES:
		if errors.is_empty(): errors.append("record_complexity_limit")
		return false
	return errors.is_empty()

static func _encode_value(value: Variant, depth: int, count: Array, errors: Array[String]) -> Variant:
	if not _within_budget(depth,count,errors): return null
	match typeof(value):
		TYPE_NIL,TYPE_BOOL,TYPE_INT: return value
		TYPE_FLOAT:
			if not is_finite(value): errors.append("non_finite_number")
			return value
		TYPE_STRING,TYPE_STRING_NAME:
			if str(value).length()>16384: errors.append("string_limit")
			return str(value)
		TYPE_VECTOR2:
			if not value.is_finite(): errors.append("non_finite_vector")
			return {"$type":"vec2","v":[value.x,value.y]}
		TYPE_VECTOR3:
			if not value.is_finite(): errors.append("non_finite_vector")
			return {"$type":"vec3","v":[value.x,value.y,value.z]}
		TYPE_TRANSFORM3D:
			if not value.is_finite(): errors.append("non_finite_transform")
			return {"$type":"transform3d","v":[value.basis.x.x,value.basis.x.y,value.basis.x.z,
				value.basis.y.x,value.basis.y.y,value.basis.y.z,value.basis.z.x,value.basis.z.y,value.basis.z.z,
				value.origin.x,value.origin.y,value.origin.z]}
		TYPE_DICTIONARY:
			var out := {}
			for key in value:
				if not key is String or key == "$type":
					errors.append("invalid_dictionary_key")
					return null
				out[key] = _encode_value(value[key],depth+1,count,errors)
			return out
		TYPE_ARRAY,TYPE_PACKED_STRING_ARRAY,TYPE_PACKED_VECTOR2_ARRAY,TYPE_PACKED_VECTOR3_ARRAY,TYPE_PACKED_INT32_ARRAY,TYPE_PACKED_INT64_ARRAY,TYPE_PACKED_FLOAT32_ARRAY,TYPE_PACKED_FLOAT64_ARRAY:
			var out: Array = []
			for item in value: out.append(_encode_value(item,depth+1,count,errors))
			return out
	errors.append("unsupported_value_type")
	return null

static func _decode_value(value: Variant, depth: int, count: Array, errors: Array[String]) -> Variant:
	if not _within_budget(depth,count,errors): return null
	if value is Dictionary:
		if value.has("$type"):
			var kind := str(value["$type"])
			var required := 2 if kind == "vec2" else (3 if kind == "vec3" else (12 if kind == "transform3d" else -1))
			if value.size()!=2 or not value.get("v") is Array or required<0 or value.v.size()!=required:
				errors.append("invalid_typed_value")
				return null
			for number in value.v:
				if not (number is int or number is float) or not is_finite(number):
					errors.append("invalid_typed_number")
					return null
			var v: Array = value.v
			if kind == "vec2": return Vector2(v[0],v[1])
			if kind == "vec3": return Vector3(v[0],v[1],v[2])
			return Transform3D(Basis(Vector3(v[0],v[1],v[2]),Vector3(v[3],v[4],v[5]),Vector3(v[6],v[7],v[8])),Vector3(v[9],v[10],v[11]))
		var out := {}
		for key in value: out[key] = _decode_value(value[key],depth+1,count,errors)
		return out
	if value is Array:
		var out: Array = []
		for item in value: out.append(_decode_value(item,depth+1,count,errors))
		return out
	if value is float and not is_finite(value): errors.append("non_finite_number")
	if value is String and value.length()>16384: errors.append("string_limit")
	return value
