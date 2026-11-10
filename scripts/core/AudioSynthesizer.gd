class_name AudioSynthesizer
extends Node

static var instance: AudioSynthesizer = null

var clips: Dictionary = {}
var sfx_players: Array[AudioStreamPlayer] = []
var max_polyphony: int = 8
var player_index: int = 0

const SAMPLE_RATE: int = 22050

func _init() -> void:
    instance = self

func _ready() -> void:
    for i in range(max_polyphony):
        var p = AudioStreamPlayer.new()
        p.bus = "Master"
        add_child(p)
        sfx_players.append(p)
    
    _generate_all_procedural_sfx()

func _generate_all_procedural_sfx() -> void:
    clips["glass_tap"] = _build_glass_tap()
    clips["wet_crunch"] = _build_wet_crunch()
    clips["organ_rip"] = _build_organ_rip()
    clips["organ_graft"] = _build_organ_graft()
    clips["insect_chirp"] = _build_insect_chirp()
    clips["creature_screech"] = _build_creature_screech()
    clips["jar_vacuum"] = _build_jar_vacuum()
    clips["acid_sizzle"] = _build_acid_sizzle()
    clips["pellet_drop"] = _build_pellet_drop()

func play_sfx(sfx_name: String, pitch_scale: float = 1.0, volume_db: float = 0.0) -> void:
    if not clips.has(sfx_name):
        return
    
    var player = sfx_players[player_index]
    player_index = (player_index + 1) % max_polyphony
    
    player.stream = clips[sfx_name]
    player.pitch_scale = pitch_scale * randf_range(0.92, 1.08)
    player.volume_db = volume_db
    player.play()

# Procedural PCM audio generation helpers (16-bit mono)
func _build_glass_tap() -> AudioStreamWAV:
    var duration = 0.4
    var total_samples = int(duration * SAMPLE_RATE)
    var pcm = PackedByteArray()
    pcm.resize(total_samples * 2)
    
    for i in range(total_samples):
        var t = float(i) / float(SAMPLE_RATE)
        var env = exp(-t * 18.0) # Sharp exponential ring
        # Bell-like glass fundamental + high overtone
        var s1 = sin(2.0 * PI * 2150.0 * t)
        var s2 = sin(2.0 * PI * 4800.0 * t) * 0.4
        var s3 = sin(2.0 * PI * 7200.0 * t) * 0.2
        var sample = (s1 + s2 + s3) * env * 0.8
        
        var val = clampi(int(sample * 32767.0), -32768, 32767)
        pcm.encode_s16(i * 2, val)
        
    return _create_wav_from_pcm(pcm)

func _build_wet_crunch() -> AudioStreamWAV:
    var duration = 0.35
    var total_samples = int(duration * SAMPLE_RATE)
    var pcm = PackedByteArray()
    pcm.resize(total_samples * 2)
    
    for i in range(total_samples):
        var t = float(i) / float(SAMPLE_RATE)
        var env = exp(-t * 12.0)
        # Low crunch noise with frequency drop
        var freq = lerpf(380.0, 70.0, t / duration)
        var noise = randf_range(-1.0, 1.0) * 0.5
        var tone = sin(2.0 * PI * freq * t) * 0.5
        var squelch = sin(2.0 * PI * (freq * 2.8) * t) * 0.3
        var sample = (noise + tone + squelch) * env
        
        var val = clampi(int(sample * 32767.0), -32768, 32767)
        pcm.encode_s16(i * 2, val)
        
    return _create_wav_from_pcm(pcm)

func _build_organ_rip() -> AudioStreamWAV:
    var duration = 0.5
    var total_samples = int(duration * SAMPLE_RATE)
    var pcm = PackedByteArray()
    pcm.resize(total_samples * 2)
    
    for i in range(total_samples):
        var t = float(i) / float(SAMPLE_RATE)
        var env = clampf(t * 15.0, 0.0, 1.0) * exp(-t * 5.0)
        # Wet tearing sound
        var noise = randf_range(-1.0, 1.0) * 0.6
        var squish = sin(2.0 * PI * (320.0 + sin(t * 60.0) * 120.0) * t) * 0.4
        var snap = 1.0 if (i > 800 and i < 1100) else 0.0
        var sample = (noise + squish + snap * 0.8) * env
        
        var val = clampi(int(sample * 32767.0), -32768, 32767)
        pcm.encode_s16(i * 2, val)
        
    return _create_wav_from_pcm(pcm)

func _build_organ_graft() -> AudioStreamWAV:
    var duration = 0.45
    var total_samples = int(duration * SAMPLE_RATE)
    var pcm = PackedByteArray()
    pcm.resize(total_samples * 2)
    
    for i in range(total_samples):
        var t = float(i) / float(SAMPLE_RATE)
        var env = exp(-t * 6.5)
        # Upward wet squelch suction
        var freq = lerpf(120.0, 520.0, t / duration)
        var tone = sin(2.0 * PI * freq * t) * 0.5
        var bubble = sin(2.0 * PI * (freq * 1.8) * t + sin(t * 40.0) * 4.0) * 0.4
        var sample = (tone + bubble) * env
        
        var val = clampi(int(sample * 32767.0), -32768, 32767)
        pcm.encode_s16(i * 2, val)
        
    return _create_wav_from_pcm(pcm)

func _build_insect_chirp() -> AudioStreamWAV:
    var duration = 0.28
    var total_samples = int(duration * SAMPLE_RATE)
    var pcm = PackedByteArray()
    pcm.resize(total_samples * 2)
    
    for i in range(total_samples):
        var t = float(i) / float(SAMPLE_RATE)
        var env = sin(PI * (t / duration))
        # Insectoid FM modulation
        var mod = sin(2.0 * PI * 85.0 * t) * 800.0
        var tone = sin(2.0 * PI * (2600.0 + mod) * t) * 0.6
        var sample = tone * env
        
        var val = clampi(int(sample * 32767.0), -32768, 32767)
        pcm.encode_s16(i * 2, val)
        
    return _create_wav_from_pcm(pcm)

func _build_creature_screech() -> AudioStreamWAV:
    var duration = 0.6
    var total_samples = int(duration * SAMPLE_RATE)
    var pcm = PackedByteArray()
    pcm.resize(total_samples * 2)
    
    for i in range(total_samples):
        var t = float(i) / float(SAMPLE_RATE)
        var env = sin(PI * clampf(t / duration, 0.0, 1.0))
        var freq = lerpf(1800.0, 650.0, t / duration)
        var grit = randf_range(-0.4, 0.4)
        var tone = sin(2.0 * PI * freq * t + sin(t * 120.0) * 3.0) * 0.6
        var sample = (tone + grit) * env
        
        var val = clampi(int(sample * 32767.0), -32768, 32767)
        pcm.encode_s16(i * 2, val)
        
    return _create_wav_from_pcm(pcm)

func _build_jar_vacuum() -> AudioStreamWAV:
    var duration = 0.55
    var total_samples = int(duration * SAMPLE_RATE)
    var pcm = PackedByteArray()
    pcm.resize(total_samples * 2)
    
    for i in range(total_samples):
        var t = float(i) / float(SAMPLE_RATE)
        var env = clampf(t * 10.0, 0.0, 1.0) * exp(-t * 4.0)
        # Vacuum whoosh + celebratory brass ting
        var whoosh = randf_range(-0.35, 0.35) * exp(-t * 5.0)
        var ding = sin(2.0 * PI * 880.0 * t) * 0.4 * exp(-t * 3.0)
        var ding2 = sin(2.0 * PI * 1320.0 * t) * 0.3 * exp(-t * 4.0)
        var sample = (whoosh + ding + ding2) * env
        
        var val = clampi(int(sample * 32767.0), -32768, 32767)
        pcm.encode_s16(i * 2, val)
        
    return _create_wav_from_pcm(pcm)

func _build_acid_sizzle() -> AudioStreamWAV:
    var duration = 0.4
    var total_samples = int(duration * SAMPLE_RATE)
    var pcm = PackedByteArray()
    pcm.resize(total_samples * 2)
    
    for i in range(total_samples):
        var t = float(i) / float(SAMPLE_RATE)
        var env = exp(-t * 5.0)
        var noise = randf_range(-1.0, 1.0) * 0.5
        var sizzle = sin(2.0 * PI * 3400.0 * t) * (randf() > 0.6 ? 0.5 : 0.0)
        var sample = (noise * 0.5 + sizzle) * env
        
        var val = clampi(int(sample * 32767.0), -32768, 32767)
        pcm.encode_s16(i * 2, val)
        
    return _create_wav_from_pcm(pcm)

func _build_pellet_drop() -> AudioStreamWAV:
    var duration = 0.2
    var total_samples = int(duration * SAMPLE_RATE)
    var pcm = PackedByteArray()
    pcm.resize(total_samples * 2)
    
    for i in range(total_samples):
        var t = float(i) / float(SAMPLE_RATE)
        var env = exp(-t * 25.0)
        var tone = sin(2.0 * PI * 360.0 * t) * 0.8
        var sample = tone * env
        
        var val = clampi(int(sample * 32767.0), -32768, 32767)
        pcm.encode_s16(i * 2, val)
        
    return _create_wav_from_pcm(pcm)

func _create_wav_from_pcm(pcm: PackedByteArray) -> AudioStreamWAV:
    var wav = AudioStreamWAV.new()
    wav.format = AudioStreamWAV.FORMAT_16_BITS
    wav.mix_rate = SAMPLE_RATE
    wav.stereo = false
    wav.data = pcm
    return wav

