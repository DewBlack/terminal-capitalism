extends RefCounted

const DEBUG_ENV_VAR := "TC_DEBUG_ENABLED"
const DEBUG_ARG := "--debug-enabled"
const DEBUG_DISABLE_ARG := "--no-debug-enabled"
const DEBUG_ARG_PREFIX := "--debug-enabled="
const TRUE_LITERALS := ["1", "true", "yes", "on"]
const FALSE_LITERALS := ["0", "false", "no", "off"]

static var _resolved := false
static var _debug_enabled := false


static func set_debug_enabled(enabled: bool) -> void:
	_debug_enabled = enabled
	_resolved = true


static func reset_runtime_config() -> void:
	_resolved = false
	_debug_enabled = false


static func is_debug_enabled() -> bool:
	if not _resolved:
		_debug_enabled = _resolve_debug_enabled()
		_resolved = true
	return _debug_enabled


static func debug(message: Variant) -> void:
	if not is_debug_enabled():
		return
	var clean_message := str(message).strip_edges()
	if clean_message.is_empty():
		return
	print(clean_message)


static func debug_lines(messages: Variant) -> void:
	if not is_debug_enabled():
		return
	if not (messages is Array):
		return
	var raw_messages: Array = messages
	for message in raw_messages:
		debug(message)


static func debug_scoped(scope: String, message: String) -> void:
	debug(debug_line(scope, message))


static func debug_line(scope: String, message: String) -> String:
	var clean_scope := scope.strip_edges()
	var clean_message := message.strip_edges()
	if clean_scope.is_empty():
		return "[DEBUG] %s" % clean_message
	return "[DEBUG][%s] %s" % [clean_scope, clean_message]


static func _resolve_debug_enabled() -> bool:
	var cmdline_override: Variant = _parse_cmdline_override()
	if typeof(cmdline_override) == TYPE_BOOL:
		return bool(cmdline_override)

	var env_override: Variant = _parse_environment_override()
	if typeof(env_override) == TYPE_BOOL:
		return bool(env_override)

	return false


static func _parse_cmdline_override() -> Variant:
	var args := OS.get_cmdline_user_args()
	for raw_arg in args:
		var arg := str(raw_arg).strip_edges()
		if arg == DEBUG_ARG:
			return true
		if arg == DEBUG_DISABLE_ARG:
			return false
		if arg.begins_with(DEBUG_ARG_PREFIX):
			return _parse_bool_token(arg.substr(DEBUG_ARG_PREFIX.length()))
	return null


static func _parse_environment_override() -> Variant:
	return _parse_bool_token(OS.get_environment(DEBUG_ENV_VAR))


static func _parse_bool_token(raw_value: String) -> Variant:
	var normalized := raw_value.strip_edges().to_lower()
	if TRUE_LITERALS.has(normalized):
		return true
	if FALSE_LITERALS.has(normalized):
		return false
	return null
