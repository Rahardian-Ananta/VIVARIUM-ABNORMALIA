class_name InputRouter
extends Node3D

@export var camera_pivot: Node3D
@export var camera_3d: Camera3D
@export var terrarium_center: Vector3 = Vector3(0, 2.2, 0)
@export var min_zoom: float = 2.5
@export var max_zoom: float = 14.0

var current_distance: float = 9.0
var yaw: float = 0.0
var pitch: float = -0.35
var is_orbiting: bool = false
var last_mouse_pos: Vector2 = Vector2.ZERO

# Touch gesture tracking
var touch_points: Dictionary = {}
var initial_pinch_distance: float = 0.0
var initial_zoom_distance: float = 9.0
var last_tap_time: float = 0.0
const DOUBLE_TAP_THRESHOLD: float = 0.3

# Signal routing
signal raycast_interacted(ray_result: Dictionary, button_index: int, is_drag: bool)
signal raycast_double_tapped(world_pos: Vector3)

func _ready() -> void:
    _update_camera_transform()

func _unhandled_input(event: InputEvent) -> void:
    # Handle Mouse Events
    if event is InputEventMouseButton:
        _handle_mouse_button(event)
    elif event is InputEventMouseMotion:
        _handle_mouse_motion(event)
    # Handle Touch Events (Mobile/Tablet)
    elif event is InputEventScreenTouch:
        _handle_screen_touch(event)
    elif event is InputEventScreenDrag:
        _handle_screen_drag(event)

func _handle_mouse_button(event: InputEventMouseButton) -> void:
    var now = Time.get_ticks_msec() / 1000.0
    
    if event.button_index == MOUSE_BUTTON_RIGHT:
        is_orbiting = event.pressed
        last_mouse_pos = event.position
    elif event.button_index == MOUSE_BUTTON_MIDDLE and event.pressed:
        # Middle click triggers acoustic glass tap shockwave
        var hit = perform_raycast(event.position, 16) # Glass layer
        if hit.is_empty():
            hit = perform_raycast(event.position, 1 | 2 | 4 | 8 | 16)
        if not hit.is_empty():
            GameManager.trigger_shockwave(hit.position)
    elif event.button_index == MOUSE_BUTTON_WHEEL_UP:
        zoom(-0.6)
    elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
        zoom(0.6)
    elif event.button_index == MOUSE_BUTTON_LEFT:
        if event.pressed:
            # Check double click
            if (now - last_tap_time) < DOUBLE_TAP_THRESHOLD:
                var hit = perform_raycast(event.position, 16)
                if hit.is_empty():
                    hit = perform_raycast(event.position, 1 | 16)
                if not hit.is_empty():
                    GameManager.trigger_shockwave(hit.position)
            last_tap_time = now
            
            var hit = perform_raycast(event.position)
            raycast_interacted.emit(hit, MOUSE_BUTTON_LEFT, false)
        else:
            var hit = perform_raycast(event.position)
            raycast_interacted.emit(hit, MOUSE_BUTTON_LEFT, false)

func _handle_mouse_motion(event: InputEventMouseMotion) -> void:
    if is_orbiting:
        var delta = event.relative
        yaw -= delta.x * 0.005
        pitch = clampf(pitch - delta.y * 0.005, -1.25, 0.25)
        _update_camera_transform()
    elif Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
        var hit = perform_raycast(event.position)
        raycast_interacted.emit(hit, MOUSE_BUTTON_LEFT, true)

func _handle_screen_touch(event: InputEventScreenTouch) -> void:
    var now = Time.get_ticks_msec() / 1000.0
    if event.pressed:
        touch_points[event.index] = event.position
        if touch_points.size() == 1:
            # Single touch check for double tap
            if (now - last_tap_time) < DOUBLE_TAP_THRESHOLD:
                var hit = perform_raycast(event.position, 16)
                if not hit.is_empty():
                    GameManager.trigger_shockwave(hit.position)
            last_tap_time = now
            
            var hit = perform_raycast(event.position)
            raycast_interacted.emit(hit, MOUSE_BUTTON_LEFT, false)
        elif touch_points.size() == 2:
            # Start pinch
            var keys = touch_points.keys()
            initial_pinch_distance = touch_points[keys[0]].distance_to(touch_points[keys[1]])
            initial_zoom_distance = current_distance
    else:
        touch_points.erase(event.index)
        if touch_points.size() == 0:
            var hit = perform_raycast(event.position)
            raycast_interacted.emit(hit, MOUSE_BUTTON_LEFT, false)

func _handle_screen_drag(event: InputEventScreenDrag) -> void:
    touch_points[event.index] = event.position
    if touch_points.size() == 2:
        # Two-finger drag orbits, pinch zooms
        var keys = touch_points.keys()
        var p0: Vector2 = touch_points[keys[0]]
        var p1: Vector2 = touch_points[keys[1]]
        var current_dist = p0.distance_to(p1)
        
        if initial_pinch_distance > 5.0:
            var pinch_ratio = initial_pinch_distance / maxf(current_dist, 1.0)
            current_distance = clampf(initial_zoom_distance * pinch_ratio, min_zoom, max_zoom)
        
        yaw -= event.relative.x * 0.004
        pitch = clampf(pitch - event.relative.y * 0.004, -1.25, 0.25)
        _update_camera_transform()
    elif touch_points.size() == 1:
        # Single finger drag tool
        var hit = perform_raycast(event.position)
        raycast_interacted.emit(hit, MOUSE_BUTTON_LEFT, true)

func zoom(amount: float) -> void:
    current_distance = clampf(current_distance + amount, min_zoom, max_zoom)
    _update_camera_transform()

func _update_camera_transform() -> void:
    if not camera_pivot or not camera_3d:
        return
    
    camera_pivot.global_position = terrarium_center
    camera_pivot.rotation.y = yaw
    camera_pivot.rotation.x = pitch
    camera_3d.position = Vector3(0, 0, current_distance)

func perform_raycast(screen_pos: Vector2, collision_mask: int = 0xFFFFFFFF) -> Dictionary:
    if not camera_3d:
        return {}
    
    var origin = camera_3d.project_ray_origin(screen_pos)
    var normal = camera_3d.project_ray_normal(screen_pos)
    var end = origin + normal * 50.0
    
    var space_state = get_world_3d().direct_space_state
    var query = PhysicsRayQueryParameters3D.create(origin, end, collision_mask)
    query.collide_with_areas = true
    query.collide_with_bodies = true
    return space_state.intersect_ray(query)

