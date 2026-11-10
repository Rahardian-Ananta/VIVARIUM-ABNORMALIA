class_name NaturalistHUD
extends CanvasLayer

@onready var rp_label: Label = $TopBar/Margin/HBox/RPContainer/RPLabel
@onready var pop_label: Label = $TopBar/Margin/HBox/PopContainer/PopLabel
@onready var temp_label: Label = $TopBar/Margin/HBox/ClimateContainer/TempLabel
@onready var humid_label: Label = $TopBar/Margin/HBox/ClimateContainer/HumidLabel
@onready var spore_bar: ProgressBar = $TopBar/Margin/HBox/ClimateContainer/SporeBar
@onready var notification_label: Label = $NotificationBanner/Label

@onready var btn_feed: Button = $ToolDock/Margin/HBox/FeedBtn
@onready var btn_mutagen: Button = $ToolDock/Margin/HBox/MutagenBtn
@onready var btn_tweezers: Button = $ToolDock/Margin/HBox/TweezersBtn
@onready var btn_surgery: Button = $ToolDock/Margin/HBox/SurgeryBtn
@onready var btn_glass: Button = $ToolDock/Margin/HBox/GlassTapBtn
@onready var btn_jar: Button = $ToolDock/Margin/HBox/JarScoopBtn

var notification_timer: float = 0.0

func _ready() -> void:
    GameManager.research_points_changed.connect(_on_rp_changed)
    GameManager.population_changed.connect(_on_population_changed)
    GameManager.climate_changed.connect(_on_climate_changed)
    GameManager.tool_changed.connect(_on_tool_changed)
    GameManager.surgery_mode_toggled.connect(_on_surgery_toggled)
    GameManager.notification_posted.connect(_on_notification_posted)
    
    _bind_tool_buttons()
    _on_rp_changed(GameManager.research_points)
    _on_tool_changed(GameManager.current_tool)

func _process(delta: float) -> void:
    if notification_timer > 0.0:
        notification_timer -= delta
        if notification_timer <= 0.0:
            $NotificationBanner.visible = false

func _bind_tool_buttons() -> void:
    btn_feed.pressed.connect(func(): GameManager.set_tool(GameManagerClass.OverseerTool.FEED))
    btn_mutagen.pressed.connect(func(): GameManager.set_tool(GameManagerClass.OverseerTool.MUTAGEN))
    btn_tweezers.pressed.connect(func(): GameManager.set_tool(GameManagerClass.OverseerTool.TWEEZERS))
    btn_surgery.pressed.connect(func(): GameManager.set_surgery_mode(not GameManager.surgery_mode_active))
    btn_glass.pressed.connect(func(): GameManager.set_tool(GameManagerClass.OverseerTool.GLASS_TAP))
    btn_jar.pressed.connect(func(): GameManager.set_tool(GameManagerClass.OverseerTool.JAR_SCOOP))

func _on_rp_changed(rp: int) -> void:
    rp_label.text = "RESEARCH: %d RP" % rp

func _on_population_changed(count: int, max_limit: int) -> void:
    pop_label.text = "SPECIMENS: %d / %d" % [count, max_limit]

func _on_climate_changed(temp: float, humid: float, _tox: float, spore: float) -> void:
    temp_label.text = "TEMP: %.1f°C" % temp
    humid_label.text = "HUMID: %.0f%%" % humid
    spore_bar.value = spore

func _on_tool_changed(tool: GameManagerClass.OverseerTool) -> void:
    btn_feed.flat = (tool != GameManagerClass.OverseerTool.FEED)
    btn_mutagen.flat = (tool != GameManagerClass.OverseerTool.MUTAGEN)
    btn_tweezers.flat = (tool != GameManagerClass.OverseerTool.TWEEZERS)
    btn_glass.flat = (tool != GameManagerClass.OverseerTool.GLASS_TAP)
    btn_jar.flat = (tool != GameManagerClass.OverseerTool.JAR_SCOOP)

func _on_surgery_toggled(active: bool) -> void:
    if active:
        btn_surgery.text = "⚠ SURGERY [ON]"
        btn_surgery.modulate = Color(1.0, 0.25, 0.25)
    else:
        btn_surgery.text = "SURGERY [OFF]"
        btn_surgery.modulate = Color(1.0, 1.0, 1.0)

func _on_notification_posted(msg: String, is_alert: bool) -> void:
    notification_label.text = msg
    notification_label.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3) if is_alert else Color(0.95, 0.85, 0.6))
    $NotificationBanner.visible = true
    notification_timer = 4.0

