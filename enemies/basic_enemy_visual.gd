extends Node3D
## Presentation-only gait for the basic enemy model. The gameplay root in main.gd
## remains responsible for movement, facing, collision, health, and death.

@export var gait_speed: float = 10.0
@export var gait_amount: float = 0.42

var _phase: float = 0.0
var _body_home: Vector3
var _head_home: Vector3

@onready var _body: Node3D = $Body
@onready var _head: Node3D = $Head
@onready var _left_leg: Node3D = $LeftLeg
@onready var _right_leg: Node3D = $RightLeg
@onready var _left_arm: Node3D = $LeftArm
@onready var _right_arm: Node3D = $RightArm


func _ready() -> void:
	_body_home = _body.position
	_head_home = _head.position


func _process(delta: float) -> void:
	_phase = fmod(_phase + delta * gait_speed, TAU)
	var stride := sin(_phase) * gait_amount
	_left_leg.rotation.x = stride
	_right_leg.rotation.x = -stride
	_left_arm.rotation.x = -stride * 0.58
	_right_arm.rotation.x = stride * 0.58
	_body.position = _body_home + Vector3(0.0, absf(sin(_phase)) * 0.012, 0.0)
	_head.position = _head_home + Vector3(0.0, sin(_phase * 0.5) * 0.006, 0.0)
