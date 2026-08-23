package backend;

import flixel.input.gamepad.FlxGamepadButton;
import flixel.input.gamepad.FlxGamepadInputID;
import flixel.input.gamepad.mappings.FlxGamepadMapping;
import flixel.input.keyboard.FlxKey;

class Controls
{
	//Keeping same use cases on stuff for it to be easier to understand/use
	//I'd have removed it but this makes it a lot less annoying to use in my opinion

	//You do NOT have to create these variables/getters for adding new keys,
	//but you will instead have to use:
	//   controls.justPressed("ui_up")   instead of   controls.UI_UP

	//Dumb but easily usable code, or Smart but complicated? Your choice.
	//Also idk how to use macros they're weird as fuck lol

	// Pressed buttons (directions)
	public var UI_UP_P(get, never):Bool;
	public var UI_DOWN_P(get, never):Bool;
	public var UI_LEFT_P(get, never):Bool;
	public var UI_RIGHT_P(get, never):Bool;
	public var NOTE_UP_P(get, never):Bool;
	public var NOTE_DOWN_P(get, never):Bool;
	public var NOTE_LEFT_P(get, never):Bool;
	public var NOTE_RIGHT_P(get, never):Bool;

	public var NOTE_5K_1_P(get, never):Bool;
    public var NOTE_5K_2_P(get, never):Bool;
    public var NOTE_5K_3_P(get, never):Bool;
    public var NOTE_5K_4_P(get, never):Bool;
    public var NOTE_5K_5_P(get, never):Bool;
    
    public var NOTE_6K_1_P(get, never):Bool;
    public var NOTE_6K_2_P(get, never):Bool;
    public var NOTE_6K_3_P(get, never):Bool;
    public var NOTE_6K_4_P(get, never):Bool;
    public var NOTE_6K_5_P(get, never):Bool;
    public var NOTE_6K_6_P(get, never):Bool;
    
    public var NOTE_7K_1_P(get, never):Bool;
    public var NOTE_7K_2_P(get, never):Bool;
    public var NOTE_7K_3_P(get, never):Bool;
    public var NOTE_7K_4_P(get, never):Bool;
    public var NOTE_7K_5_P(get, never):Bool;
    public var NOTE_7K_6_P(get, never):Bool;
    public var NOTE_7K_7_P(get, never):Bool;
    
    public var NOTE_8K_1_P(get, never):Bool;
    public var NOTE_8K_2_P(get, never):Bool;
    public var NOTE_8K_3_P(get, never):Bool;
    public var NOTE_8K_4_P(get, never):Bool;
    public var NOTE_8K_5_P(get, never):Bool;
    public var NOTE_8K_6_P(get, never):Bool;
    public var NOTE_8K_7_P(get, never):Bool;
    public var NOTE_8K_8_P(get, never):Bool;

	public var NOTE_9K_1_P(get, never):Bool;
	public var NOTE_9K_2_P(get, never):Bool;
	public var NOTE_9K_3_P(get, never):Bool;
	public var NOTE_9K_4_P(get, never):Bool;
	public var NOTE_9K_5_P(get, never):Bool;
	public var NOTE_9K_6_P(get, never):Bool;
	public var NOTE_9K_7_P(get, never):Bool;
	public var NOTE_9K_8_P(get, never):Bool;
	public var NOTE_9K_9_P(get, never):Bool;

	public var NOTE_10K_1_P(get, never):Bool;
	public var NOTE_10K_2_P(get, never):Bool;
	public var NOTE_10K_3_P(get, never):Bool;
	public var NOTE_10K_4_P(get, never):Bool;
	public var NOTE_10K_5_P(get, never):Bool;
	public var NOTE_10K_6_P(get, never):Bool;
	public var NOTE_10K_7_P(get, never):Bool;
	public var NOTE_10K_8_P(get, never):Bool;
	public var NOTE_10K_9_P(get, never):Bool;
	public var NOTE_10K_10_P(get, never):Bool;

	public var NOTE_11K_1_P(get, never):Bool;
	public var NOTE_11K_2_P(get, never):Bool;
	public var NOTE_11K_3_P(get, never):Bool;
	public var NOTE_11K_4_P(get, never):Bool;
	public var NOTE_11K_5_P(get, never):Bool;
	public var NOTE_11K_6_P(get, never):Bool;
	public var NOTE_11K_7_P(get, never):Bool;
	public var NOTE_11K_8_P(get, never):Bool;
	public var NOTE_11K_9_P(get, never):Bool;
	public var NOTE_11K_10_P(get, never):Bool;
	public var NOTE_11K_11_P(get, never):Bool;
	
	public var NOTE_12K_1_P(get, never):Bool;
	public var NOTE_12K_2_P(get, never):Bool;
	public var NOTE_12K_3_P(get, never):Bool;
	public var NOTE_12K_4_P(get, never):Bool;
	public var NOTE_12K_5_P(get, never):Bool;
	public var NOTE_12K_6_P(get, never):Bool;
	public var NOTE_12K_7_P(get, never):Bool;
	public var NOTE_12K_8_P(get, never):Bool;
	public var NOTE_12K_9_P(get, never):Bool;
	public var NOTE_12K_10_P(get, never):Bool;
	public var NOTE_12K_11_P(get, never):Bool;
	public var NOTE_12K_12_P(get, never):Bool;

	public var NOTE_13K_1_P(get, never):Bool;
	public var NOTE_13K_2_P(get, never):Bool;
	public var NOTE_13K_3_P(get, never):Bool;
	public var NOTE_13K_4_P(get, never):Bool;
	public var NOTE_13K_5_P(get, never):Bool;
	public var NOTE_13K_6_P(get, never):Bool;
	public var NOTE_13K_7_P(get, never):Bool;
	public var NOTE_13K_8_P(get, never):Bool;
	public var NOTE_13K_9_P(get, never):Bool;
	public var NOTE_13K_10_P(get, never):Bool;
	public var NOTE_13K_11_P(get, never):Bool;
	public var NOTE_13K_12_P(get, never):Bool;
	public var NOTE_13K_13_P(get, never):Bool;

	public var NOTE_14K_1_P(get, never):Bool;
	public var NOTE_14K_2_P(get, never):Bool;
	public var NOTE_14K_3_P(get, never):Bool;
	public var NOTE_14K_4_P(get, never):Bool;
	public var NOTE_14K_5_P(get, never):Bool;
	public var NOTE_14K_6_P(get, never):Bool;
	public var NOTE_14K_7_P(get, never):Bool;
	public var NOTE_14K_8_P(get, never):Bool;
	public var NOTE_14K_9_P(get, never):Bool;
	public var NOTE_14K_10_P(get, never):Bool;
	public var NOTE_14K_11_P(get, never):Bool;
	public var NOTE_14K_12_P(get, never):Bool;
	public var NOTE_14K_13_P(get, never):Bool;
	public var NOTE_14K_14_P(get, never):Bool;

	public var NOTE_15K_1_P(get, never):Bool;
	public var NOTE_15K_2_P(get, never):Bool;
	public var NOTE_15K_3_P(get, never):Bool;
	public var NOTE_15K_4_P(get, never):Bool;
	public var NOTE_15K_5_P(get, never):Bool;
	public var NOTE_15K_6_P(get, never):Bool;
	public var NOTE_15K_7_P(get, never):Bool;
	public var NOTE_15K_8_P(get, never):Bool;
	public var NOTE_15K_9_P(get, never):Bool;
	public var NOTE_15K_10_P(get, never):Bool;
	public var NOTE_15K_11_P(get, never):Bool;
	public var NOTE_15K_12_P(get, never):Bool;
	public var NOTE_15K_13_P(get, never):Bool;
	public var NOTE_15K_14_P(get, never):Bool;
	public var NOTE_15K_15_P(get, never):Bool;

	public var NOTE_16K_1_P(get, never):Bool;
	public var NOTE_16K_2_P(get, never):Bool;
	public var NOTE_16K_3_P(get, never):Bool;
	public var NOTE_16K_4_P(get, never):Bool;
	public var NOTE_16K_5_P(get, never):Bool;
	public var NOTE_16K_6_P(get, never):Bool;
	public var NOTE_16K_7_P(get, never):Bool;
	public var NOTE_16K_8_P(get, never):Bool;
	public var NOTE_16K_9_P(get, never):Bool;
	public var NOTE_16K_10_P(get, never):Bool;
	public var NOTE_16K_11_P(get, never):Bool;
	public var NOTE_16K_12_P(get, never):Bool;
	public var NOTE_16K_13_P(get, never):Bool;
	public var NOTE_16K_14_P(get, never):Bool;
	public var NOTE_16K_15_P(get, never):Bool;
	public var NOTE_16K_16_P(get, never):Bool;

	private function get_UI_UP_P() return justPressed('ui_up');
	private function get_UI_DOWN_P() return justPressed('ui_down');
	private function get_UI_LEFT_P() return justPressed('ui_left');
	private function get_UI_RIGHT_P() return justPressed('ui_right');
	private function get_NOTE_UP_P() return justPressed('note_up');
	private function get_NOTE_DOWN_P() return justPressed('note_down');
	private function get_NOTE_LEFT_P() return justPressed('note_left');
	private function get_NOTE_RIGHT_P() return justPressed('note_right');

	private function get_NOTE_5K_1_P() return justPressed('note_5k_1');
	private function get_NOTE_5K_2_P() return justPressed('note_5k_2');
	private function get_NOTE_5K_3_P() return justPressed('note_5k_3');
	private function get_NOTE_5K_4_P() return justPressed('note_5k_4');
	private function get_NOTE_5K_5_P() return justPressed('note_5k_5');

	private function get_NOTE_6K_1_P() return justPressed('note_6k_1');
	private function get_NOTE_6K_2_P() return justPressed('note_6k_2');
	private function get_NOTE_6K_3_P() return justPressed('note_6k_3');
	private function get_NOTE_6K_4_P() return justPressed('note_6k_4');
	private function get_NOTE_6K_5_P() return justPressed('note_6k_5');
	private function get_NOTE_6K_6_P() return justPressed('note_6k_6');

	private function get_NOTE_7K_1_P() return justPressed('note_7k_1');
	private function get_NOTE_7K_2_P() return justPressed('note_7k_2');
	private function get_NOTE_7K_3_P() return justPressed('note_7k_3');
	private function get_NOTE_7K_4_P() return justPressed('note_7k_4');
	private function get_NOTE_7K_5_P() return justPressed('note_7k_5');
	private function get_NOTE_7K_6_P() return justPressed('note_7k_6');
	private function get_NOTE_7K_7_P() return justPressed('note_7k_7');

	private function get_NOTE_8K_1_P() return justPressed('note_8k_1');
	private function get_NOTE_8K_2_P() return justPressed('note_8k_2');
	private function get_NOTE_8K_3_P() return justPressed('note_8k_3');
	private function get_NOTE_8K_4_P() return justPressed('note_8k_4');
	private function get_NOTE_8K_5_P() return justPressed('note_8k_5');
	private function get_NOTE_8K_6_P() return justPressed('note_8k_6');
	private function get_NOTE_8K_7_P() return justPressed('note_8k_7');
	private function get_NOTE_8K_8_P() return justPressed('note_8k_8');

	private function get_NOTE_9K_1_P() return justPressed('note_9k_1');
	private function get_NOTE_9K_2_P() return justPressed('note_9k_2');
	private function get_NOTE_9K_3_P() return justPressed('note_9k_3');
	private function get_NOTE_9K_4_P() return justPressed('note_9k_4');
	private function get_NOTE_9K_5_P() return justPressed('note_9k_5');
	private function get_NOTE_9K_6_P() return justPressed('note_9k_6');
	private function get_NOTE_9K_7_P() return justPressed('note_9k_7');
	private function get_NOTE_9K_8_P() return justPressed('note_9k_8');
	private function get_NOTE_9K_9_P() return justPressed('note_9k_9');

	private function get_NOTE_10K_1_P() return justPressed('note_10k_1');
	private function get_NOTE_10K_2_P() return justPressed('note_10k_2');
	private function get_NOTE_10K_3_P() return justPressed('note_10k_3');
	private function get_NOTE_10K_4_P() return justPressed('note_10k_4');
	private function get_NOTE_10K_5_P() return justPressed('note_10k_5');
	private function get_NOTE_10K_6_P() return justPressed('note_10k_6');
	private function get_NOTE_10K_7_P() return justPressed('note_10k_7');
	private function get_NOTE_10K_8_P() return justPressed('note_10k_8');
	private function get_NOTE_10K_9_P() return justPressed('note_10k_9');
	private function get_NOTE_10K_10_P() return justPressed('note_10k_10');

	private function get_NOTE_11K_1_P() return justPressed('note_11k_1');
	private function get_NOTE_11K_2_P() return justPressed('note_11k_2');
	private function get_NOTE_11K_3_P() return justPressed('note_11k_3');
	private function get_NOTE_11K_4_P() return justPressed('note_11k_4');
	private function get_NOTE_11K_5_P() return justPressed('note_11k_5');
	private function get_NOTE_11K_6_P() return justPressed('note_11k_6');
	private function get_NOTE_11K_7_P() return justPressed('note_11k_7');
	private function get_NOTE_11K_8_P() return justPressed('note_11k_8');
	private function get_NOTE_11K_9_P() return justPressed('note_11k_9');
	private function get_NOTE_11K_10_P() return justPressed('note_11k_10');
	private function get_NOTE_11K_11_P() return justPressed('note_11k_11');

	private function get_NOTE_12K_1_P() return justPressed('note_12k_1');
	private function get_NOTE_12K_2_P() return justPressed('note_12k_2');
	private function get_NOTE_12K_3_P() return justPressed('note_12k_3');
	private function get_NOTE_12K_4_P() return justPressed('note_12k_4');
	private function get_NOTE_12K_5_P() return justPressed('note_12k_5');
	private function get_NOTE_12K_6_P() return justPressed('note_12k_6');
	private function get_NOTE_12K_7_P() return justPressed('note_12k_7');
	private function get_NOTE_12K_8_P() return justPressed('note_12k_8');
	private function get_NOTE_12K_9_P() return justPressed('note_12k_9');
	private function get_NOTE_12K_10_P() return justPressed('note_12k_10');
	private function get_NOTE_12K_11_P() return justPressed('note_12k_11');
	private function get_NOTE_12K_12_P() return justPressed('note_12k_12');

	private function get_NOTE_13K_1_P() return justPressed('note_13k_1');
	private function get_NOTE_13K_2_P() return justPressed('note_13k_2');
	private function get_NOTE_13K_3_P() return justPressed('note_13k_3');
	private function get_NOTE_13K_4_P() return justPressed('note_13k_4');
	private function get_NOTE_13K_5_P() return justPressed('note_13k_5');
	private function get_NOTE_13K_6_P() return justPressed('note_13k_6');
	private function get_NOTE_13K_7_P() return justPressed('note_13k_7');
	private function get_NOTE_13K_8_P() return justPressed('note_13k_8');
	private function get_NOTE_13K_9_P() return justPressed('note_13k_9');
	private function get_NOTE_13K_10_P() return justPressed('note_13k_10');
	private function get_NOTE_13K_11_P() return justPressed('note_13k_11');
	private function get_NOTE_13K_12_P() return justPressed('note_13k_12');
	private function get_NOTE_13K_13_P() return justPressed('note_13k_13');

	private function get_NOTE_14K_1_P() return justPressed('note_14k_1');
	private function get_NOTE_14K_2_P() return justPressed('note_14k_2');
	private function get_NOTE_14K_3_P() return justPressed('note_14k_3');
	private function get_NOTE_14K_4_P() return justPressed('note_14k_4');
	private function get_NOTE_14K_5_P() return justPressed('note_14k_5');
	private function get_NOTE_14K_6_P() return justPressed('note_14k_6');
	private function get_NOTE_14K_7_P() return justPressed('note_14k_7');
	private function get_NOTE_14K_8_P() return justPressed('note_14k_8');
	private function get_NOTE_14K_9_P() return justPressed('note_14k_9');
	private function get_NOTE_14K_10_P() return justPressed('note_14k_10');
	private function get_NOTE_14K_11_P() return justPressed('note_14k_11');
	private function get_NOTE_14K_12_P() return justPressed('note_14k_12');
	private function get_NOTE_14K_13_P() return justPressed('note_14k_13');
	private function get_NOTE_14K_14_P() return justPressed('note_14k_14');

	private function get_NOTE_15K_1_P() return justPressed('note_15k_1');
	private function get_NOTE_15K_2_P() return justPressed('note_15k_2');
	private function get_NOTE_15K_3_P() return justPressed('note_15k_3');
	private function get_NOTE_15K_4_P() return justPressed('note_15k_4');
	private function get_NOTE_15K_5_P() return justPressed('note_15k_5');
	private function get_NOTE_15K_6_P() return justPressed('note_15k_6');
	private function get_NOTE_15K_7_P() return justPressed('note_15k_7');
	private function get_NOTE_15K_8_P() return justPressed('note_15k_8');
	private function get_NOTE_15K_9_P() return justPressed('note_15k_9');
	private function get_NOTE_15K_10_P() return justPressed('note_15k_10');
	private function get_NOTE_15K_11_P() return justPressed('note_15k_11');
	private function get_NOTE_15K_12_P() return justPressed('note_15k_12');
	private function get_NOTE_15K_13_P() return justPressed('note_15k_13');
	private function get_NOTE_15K_14_P() return justPressed('note_15k_14');
	private function get_NOTE_15K_15_P() return justPressed('note_15k_15');

	private function get_NOTE_16K_1_P() return justPressed('note_16k_1');
	private function get_NOTE_16K_2_P() return justPressed('note_16k_2');
	private function get_NOTE_16K_3_P() return justPressed('note_16k_3');
	private function get_NOTE_16K_4_P() return justPressed('note_16k_4');
	private function get_NOTE_16K_5_P() return justPressed('note_16k_5');
	private function get_NOTE_16K_6_P() return justPressed('note_16k_6');
	private function get_NOTE_16K_7_P() return justPressed('note_16k_7');
	private function get_NOTE_16K_8_P() return justPressed('note_16k_8');
	private function get_NOTE_16K_9_P() return justPressed('note_16k_9');
	private function get_NOTE_16K_10_P() return justPressed('note_16k_10');
	private function get_NOTE_16K_11_P() return justPressed('note_16k_11');
	private function get_NOTE_16K_12_P() return justPressed('note_16k_12');
	private function get_NOTE_16K_13_P() return justPressed('note_16k_13');
	private function get_NOTE_16K_14_P() return justPressed('note_16k_14');
	private function get_NOTE_16K_15_P() return justPressed('note_16k_15');
	private function get_NOTE_16K_16_P() return justPressed('note_16k_16');

	// Held buttons (directions)
	public var UI_UP(get, never):Bool;
	public var UI_DOWN(get, never):Bool;
	public var UI_LEFT(get, never):Bool;
	public var UI_RIGHT(get, never):Bool;
	public var NOTE_UP(get, never):Bool;
	public var NOTE_DOWN(get, never):Bool;
	public var NOTE_LEFT(get, never):Bool;
	public var NOTE_RIGHT(get, never):Bool;

	public var NOTE_5K_1(get, never):Bool;
    public var NOTE_5K_2(get, never):Bool;
    public var NOTE_5K_3(get, never):Bool;
    public var NOTE_5K_4(get, never):Bool;
    public var NOTE_5K_5(get, never):Bool;
    
    public var NOTE_6K_1(get, never):Bool;
    public var NOTE_6K_2(get, never):Bool;
    public var NOTE_6K_3(get, never):Bool;
    public var NOTE_6K_4(get, never):Bool;
    public var NOTE_6K_5(get, never):Bool;
    public var NOTE_6K_6(get, never):Bool;
    
    public var NOTE_7K_1(get, never):Bool;
    public var NOTE_7K_2(get, never):Bool;
    public var NOTE_7K_3(get, never):Bool;
    public var NOTE_7K_4(get, never):Bool;
    public var NOTE_7K_5(get, never):Bool;
    public var NOTE_7K_6(get, never):Bool;
    public var NOTE_7K_7(get, never):Bool;
    
    public var NOTE_8K_1(get, never):Bool;
    public var NOTE_8K_2(get, never):Bool;
    public var NOTE_8K_3(get, never):Bool;
    public var NOTE_8K_4(get, never):Bool;
    public var NOTE_8K_5(get, never):Bool;
    public var NOTE_8K_6(get, never):Bool;
    public var NOTE_8K_7(get, never):Bool;
    public var NOTE_8K_8(get, never):Bool;

	public var NOTE_9K_1(get, never):Bool;
	public var NOTE_9K_2(get, never):Bool;
	public var NOTE_9K_3(get, never):Bool;
	public var NOTE_9K_4(get, never):Bool;
	public var NOTE_9K_5(get, never):Bool;
	public var NOTE_9K_6(get, never):Bool;
	public var NOTE_9K_7(get, never):Bool;
	public var NOTE_9K_8(get, never):Bool;
	public var NOTE_9K_9(get, never):Bool;

	public var NOTE_10K_1(get, never):Bool;
	public var NOTE_10K_2(get, never):Bool;
	public var NOTE_10K_3(get, never):Bool;
	public var NOTE_10K_4(get, never):Bool;
	public var NOTE_10K_5(get, never):Bool;
	public var NOTE_10K_6(get, never):Bool;
	public var NOTE_10K_7(get, never):Bool;
	public var NOTE_10K_8(get, never):Bool;
	public var NOTE_10K_9(get, never):Bool;
	public var NOTE_10K_10(get, never):Bool;

	public var NOTE_11K_1(get, never):Bool;
	public var NOTE_11K_2(get, never):Bool;
	public var NOTE_11K_3(get, never):Bool;
	public var NOTE_11K_4(get, never):Bool;
	public var NOTE_11K_5(get, never):Bool;
	public var NOTE_11K_6(get, never):Bool;
	public var NOTE_11K_7(get, never):Bool;
	public var NOTE_11K_8(get, never):Bool;
	public var NOTE_11K_9(get, never):Bool;
	public var NOTE_11K_10(get, never):Bool;
	public var NOTE_11K_11(get, never):Bool;
	
	public var NOTE_12K_1(get, never):Bool;
	public var NOTE_12K_2(get, never):Bool;
	public var NOTE_12K_3(get, never):Bool;
	public var NOTE_12K_4(get, never):Bool;
	public var NOTE_12K_5(get, never):Bool;
	public var NOTE_12K_6(get, never):Bool;
	public var NOTE_12K_7(get, never):Bool;
	public var NOTE_12K_8(get, never):Bool;
	public var NOTE_12K_9(get, never):Bool;
	public var NOTE_12K_10(get, never):Bool;
	public var NOTE_12K_11(get, never):Bool;
	public var NOTE_12K_12(get, never):Bool;

	public var NOTE_13K_1(get, never):Bool;
	public var NOTE_13K_2(get, never):Bool;
	public var NOTE_13K_3(get, never):Bool;
	public var NOTE_13K_4(get, never):Bool;
	public var NOTE_13K_5(get, never):Bool;
	public var NOTE_13K_6(get, never):Bool;
	public var NOTE_13K_7(get, never):Bool;
	public var NOTE_13K_8(get, never):Bool;
	public var NOTE_13K_9(get, never):Bool;
	public var NOTE_13K_10(get, never):Bool;
	public var NOTE_13K_11(get, never):Bool;
	public var NOTE_13K_12(get, never):Bool;
	public var NOTE_13K_13(get, never):Bool;

	public var NOTE_14K_1(get, never):Bool;
	public var NOTE_14K_2(get, never):Bool;
	public var NOTE_14K_3(get, never):Bool;
	public var NOTE_14K_4(get, never):Bool;
	public var NOTE_14K_5(get, never):Bool;
	public var NOTE_14K_6(get, never):Bool;
	public var NOTE_14K_7(get, never):Bool;
	public var NOTE_14K_8(get, never):Bool;
	public var NOTE_14K_9(get, never):Bool;
	public var NOTE_14K_10(get, never):Bool;
	public var NOTE_14K_11(get, never):Bool;
	public var NOTE_14K_12(get, never):Bool;
	public var NOTE_14K_13(get, never):Bool;
	public var NOTE_14K_14(get, never):Bool;

	public var NOTE_15K_1(get, never):Bool;
	public var NOTE_15K_2(get, never):Bool;
	public var NOTE_15K_3(get, never):Bool;
	public var NOTE_15K_4(get, never):Bool;
	public var NOTE_15K_5(get, never):Bool;
	public var NOTE_15K_6(get, never):Bool;
	public var NOTE_15K_7(get, never):Bool;
	public var NOTE_15K_8(get, never):Bool;
	public var NOTE_15K_9(get, never):Bool;
	public var NOTE_15K_10(get, never):Bool;
	public var NOTE_15K_11(get, never):Bool;
	public var NOTE_15K_12(get, never):Bool;
	public var NOTE_15K_13(get, never):Bool;
	public var NOTE_15K_14(get, never):Bool;
	public var NOTE_15K_15(get, never):Bool;

	public var NOTE_16K_1(get, never):Bool;
	public var NOTE_16K_2(get, never):Bool;
	public var NOTE_16K_3(get, never):Bool;
	public var NOTE_16K_4(get, never):Bool;
	public var NOTE_16K_5(get, never):Bool;
	public var NOTE_16K_6(get, never):Bool;
	public var NOTE_16K_7(get, never):Bool;
	public var NOTE_16K_8(get, never):Bool;
	public var NOTE_16K_9(get, never):Bool;
	public var NOTE_16K_10(get, never):Bool;
	public var NOTE_16K_11(get, never):Bool;
	public var NOTE_16K_12(get, never):Bool;
	public var NOTE_16K_13(get, never):Bool;
	public var NOTE_16K_14(get, never):Bool;
	public var NOTE_16K_15(get, never):Bool;
	public var NOTE_16K_16(get, never):Bool;

	private function get_UI_UP() return pressed('ui_up');
	private function get_UI_DOWN() return pressed('ui_down');
	private function get_UI_LEFT() return pressed('ui_left');
	private function get_UI_RIGHT() return pressed('ui_right');
	private function get_NOTE_UP() return pressed('note_up');
	private function get_NOTE_DOWN() return pressed('note_down');
	private function get_NOTE_LEFT() return pressed('note_left');
	private function get_NOTE_RIGHT() return pressed('note_right');
	

	// Released buttons (directions)
	public var UI_UP_R(get, never):Bool;
	public var UI_DOWN_R(get, never):Bool;
	public var UI_LEFT_R(get, never):Bool;
	public var UI_RIGHT_R(get, never):Bool;
	public var NOTE_UP_R(get, never):Bool;
	public var NOTE_DOWN_R(get, never):Bool;
	public var NOTE_LEFT_R(get, never):Bool;
	public var NOTE_RIGHT_R(get, never):Bool;

	public var NOTE_5K_1_R(get, never):Bool;
    public var NOTE_5K_2_R(get, never):Bool;
    public var NOTE_5K_3_R(get, never):Bool;
    public var NOTE_5K_4_R(get, never):Bool;
    public var NOTE_5K_5_R(get, never):Bool;
    
    public var NOTE_6K_1_R(get, never):Bool;
    public var NOTE_6K_2_R(get, never):Bool;
    public var NOTE_6K_3_R(get, never):Bool;
    public var NOTE_6K_4_R(get, never):Bool;
    public var NOTE_6K_5_R(get, never):Bool;
    public var NOTE_6K_6_R(get, never):Bool;
    
    public var NOTE_7K_1_R(get, never):Bool;
    public var NOTE_7K_2_R(get, never):Bool;
    public var NOTE_7K_3_R(get, never):Bool;
    public var NOTE_7K_4_R(get, never):Bool;
    public var NOTE_7K_5_R(get, never):Bool;
    public var NOTE_7K_6_R(get, never):Bool;
    public var NOTE_7K_7_R(get, never):Bool;
    
    public var NOTE_8K_1_R(get, never):Bool;
    public var NOTE_8K_2_R(get, never):Bool;
    public var NOTE_8K_3_R(get, never):Bool;
    public var NOTE_8K_4_R(get, never):Bool;
    public var NOTE_8K_5_R(get, never):Bool;
    public var NOTE_8K_6_R(get, never):Bool;
    public var NOTE_8K_7_R(get, never):Bool;
    public var NOTE_8K_8_R(get, never):Bool;

	public var NOTE_9K_1_R(get, never):Bool;
	public var NOTE_9K_2_R(get, never):Bool;
	public var NOTE_9K_3_R(get, never):Bool;
	public var NOTE_9K_4_R(get, never):Bool;
	public var NOTE_9K_5_R(get, never):Bool;
	public var NOTE_9K_6_R(get, never):Bool;
	public var NOTE_9K_7_R(get, never):Bool;
	public var NOTE_9K_8_R(get, never):Bool;
	public var NOTE_9K_9_R(get, never):Bool;

	public var NOTE_10K_1_R(get, never):Bool;
	public var NOTE_10K_2_R(get, never):Bool;
	public var NOTE_10K_3_R(get, never):Bool;
	public var NOTE_10K_4_R(get, never):Bool;
	public var NOTE_10K_5_R(get, never):Bool;
	public var NOTE_10K_6_R(get, never):Bool;
	public var NOTE_10K_7_R(get, never):Bool;
	public var NOTE_10K_8_R(get, never):Bool;
	public var NOTE_10K_9_R(get, never):Bool;
	public var NOTE_10K_10_R(get, never):Bool;

	public var NOTE_11K_1_R(get, never):Bool;
	public var NOTE_11K_2_R(get, never):Bool;
	public var NOTE_11K_3_R(get, never):Bool;
	public var NOTE_11K_4_R(get, never):Bool;
	public var NOTE_11K_5_R(get, never):Bool;
	public var NOTE_11K_6_R(get, never):Bool;
	public var NOTE_11K_7_R(get, never):Bool;
	public var NOTE_11K_8_R(get, never):Bool;
	public var NOTE_11K_9_R(get, never):Bool;
	public var NOTE_11K_10_R(get, never):Bool;
	public var NOTE_11K_11_R(get, never):Bool;
	
	public var NOTE_12K_1_R(get, never):Bool;
	public var NOTE_12K_2_R(get, never):Bool;
	public var NOTE_12K_3_R(get, never):Bool;
	public var NOTE_12K_4_R(get, never):Bool;
	public var NOTE_12K_5_R(get, never):Bool;
	public var NOTE_12K_6_R(get, never):Bool;
	public var NOTE_12K_7_R(get, never):Bool;
	public var NOTE_12K_8_R(get, never):Bool;
	public var NOTE_12K_9_R(get, never):Bool;
	public var NOTE_12K_10_R(get, never):Bool;
	public var NOTE_12K_11_R(get, never):Bool;
	public var NOTE_12K_12_R(get, never):Bool;

	public var NOTE_13K_1_R(get, never):Bool;
	public var NOTE_13K_2_R(get, never):Bool;
	public var NOTE_13K_3_R(get, never):Bool;
	public var NOTE_13K_4_R(get, never):Bool;
	public var NOTE_13K_5_R(get, never):Bool;
	public var NOTE_13K_6_R(get, never):Bool;
	public var NOTE_13K_7_R(get, never):Bool;
	public var NOTE_13K_8_R(get, never):Bool;
	public var NOTE_13K_9_R(get, never):Bool;
	public var NOTE_13K_10_R(get, never):Bool;
	public var NOTE_13K_11_R(get, never):Bool;
	public var NOTE_13K_12_R(get, never):Bool;
	public var NOTE_13K_13_R(get, never):Bool;

	public var NOTE_14K_1_R(get, never):Bool;
	public var NOTE_14K_2_R(get, never):Bool;
	public var NOTE_14K_3_R(get, never):Bool;
	public var NOTE_14K_4_R(get, never):Bool;
	public var NOTE_14K_5_R(get, never):Bool;
	public var NOTE_14K_6_R(get, never):Bool;
	public var NOTE_14K_7_R(get, never):Bool;
	public var NOTE_14K_8_R(get, never):Bool;
	public var NOTE_14K_9_R(get, never):Bool;
	public var NOTE_14K_10_R(get, never):Bool;
	public var NOTE_14K_11_R(get, never):Bool;
	public var NOTE_14K_12_R(get, never):Bool;
	public var NOTE_14K_13_R(get, never):Bool;
	public var NOTE_14K_14_R(get, never):Bool;

	public var NOTE_15K_1_R(get, never):Bool;
	public var NOTE_15K_2_R(get, never):Bool;
	public var NOTE_15K_3_R(get, never):Bool;
	public var NOTE_15K_4_R(get, never):Bool;
	public var NOTE_15K_5_R(get, never):Bool;
	public var NOTE_15K_6_R(get, never):Bool;
	public var NOTE_15K_7_R(get, never):Bool;
	public var NOTE_15K_8_R(get, never):Bool;
	public var NOTE_15K_9_R(get, never):Bool;
	public var NOTE_15K_10_R(get, never):Bool;
	public var NOTE_15K_11_R(get, never):Bool;
	public var NOTE_15K_12_R(get, never):Bool;
	public var NOTE_15K_13_R(get, never):Bool;
	public var NOTE_15K_14_R(get, never):Bool;
	public var NOTE_15K_15_R(get, never):Bool;

	public var NOTE_16K_1_R(get, never):Bool;
	public var NOTE_16K_2_R(get, never):Bool;
	public var NOTE_16K_3_R(get, never):Bool;
	public var NOTE_16K_4_R(get, never):Bool;
	public var NOTE_16K_5_R(get, never):Bool;
	public var NOTE_16K_6_R(get, never):Bool;
	public var NOTE_16K_7_R(get, never):Bool;
	public var NOTE_16K_8_R(get, never):Bool;
	public var NOTE_16K_9_R(get, never):Bool;
	public var NOTE_16K_10_R(get, never):Bool;
	public var NOTE_16K_11_R(get, never):Bool;
	public var NOTE_16K_12_R(get, never):Bool;
	public var NOTE_16K_13_R(get, never):Bool;
	public var NOTE_16K_14_R(get, never):Bool;
	public var NOTE_16K_15_R(get, never):Bool;
	public var NOTE_16K_16_R(get, never):Bool;

	private function get_UI_UP_R() return justReleased('ui_up');
	private function get_UI_DOWN_R() return justReleased('ui_down');
	private function get_UI_LEFT_R() return justReleased('ui_left');
	private function get_UI_RIGHT_R() return justReleased('ui_right');
	private function get_NOTE_UP_R() return justReleased('note_up');
	private function get_NOTE_DOWN_R() return justReleased('note_down');
	private function get_NOTE_LEFT_R() return justReleased('note_left');
	private function get_NOTE_RIGHT_R() return justReleased('note_right');

	// 5K
	private function get_NOTE_5K_1() return pressed('note_5k_1');
	private function get_NOTE_5K_2() return pressed('note_5k_2');
	private function get_NOTE_5K_3() return pressed('note_5k_3');
	private function get_NOTE_5K_4() return pressed('note_5k_4');
	private function get_NOTE_5K_5() return pressed('note_5k_5');

	private function get_NOTE_5K_1_R() return justReleased('note_5k_1');
	private function get_NOTE_5K_2_R() return justReleased('note_5k_2');
	private function get_NOTE_5K_3_R() return justReleased('note_5k_3');
	private function get_NOTE_5K_4_R() return justReleased('note_5k_4');
	private function get_NOTE_5K_5_R() return justReleased('note_5k_5');

	// 6K
	private function get_NOTE_6K_1() return pressed('note_6k_1');
	private function get_NOTE_6K_2() return pressed('note_6k_2');
	private function get_NOTE_6K_3() return pressed('note_6k_3');
	private function get_NOTE_6K_4() return pressed('note_6k_4');
	private function get_NOTE_6K_5() return pressed('note_6k_5');
	private function get_NOTE_6K_6() return pressed('note_6k_6');

	private function get_NOTE_6K_1_R() return justReleased('note_6k_1');
	private function get_NOTE_6K_2_R() return justReleased('note_6k_2');
	private function get_NOTE_6K_3_R() return justReleased('note_6k_3');
	private function get_NOTE_6K_4_R() return justReleased('note_6k_4');
	private function get_NOTE_6K_5_R() return justReleased('note_6k_5');
	private function get_NOTE_6K_6_R() return justReleased('note_6k_6');

	// 7K
	private function get_NOTE_7K_1() return pressed('note_7k_1');
	private function get_NOTE_7K_2() return pressed('note_7k_2');
	private function get_NOTE_7K_3() return pressed('note_7k_3');
	private function get_NOTE_7K_4() return pressed('note_7k_4');
	private function get_NOTE_7K_5() return pressed('note_7k_5');
	private function get_NOTE_7K_6() return pressed('note_7k_6');
	private function get_NOTE_7K_7() return pressed('note_7k_7');

	private function get_NOTE_7K_1_R() return justReleased('note_7k_1');
	private function get_NOTE_7K_2_R() return justReleased('note_7k_2');
	private function get_NOTE_7K_3_R() return justReleased('note_7k_3');
	private function get_NOTE_7K_4_R() return justReleased('note_7k_4');
	private function get_NOTE_7K_5_R() return justReleased('note_7k_5');
	private function get_NOTE_7K_6_R() return justReleased('note_7k_6');
	private function get_NOTE_7K_7_R() return justReleased('note_7k_7');

	// 8K
	private function get_NOTE_8K_1() return pressed('note_8k_1');
	private function get_NOTE_8K_2() return pressed('note_8k_2');
	private function get_NOTE_8K_3() return pressed('note_8k_3');
	private function get_NOTE_8K_4() return pressed('note_8k_4');
	private function get_NOTE_8K_5() return pressed('note_8k_5');
	private function get_NOTE_8K_6() return pressed('note_8k_6');
	private function get_NOTE_8K_7() return pressed('note_8k_7');
	private function get_NOTE_8K_8() return pressed('note_8k_8');

	private function get_NOTE_8K_1_R() return justReleased('note_8k_1');
	private function get_NOTE_8K_2_R() return justReleased('note_8k_2');
	private function get_NOTE_8K_3_R() return justReleased('note_8k_3');
	private function get_NOTE_8K_4_R() return justReleased('note_8k_4');
	private function get_NOTE_8K_5_R() return justReleased('note_8k_5');
	private function get_NOTE_8K_6_R() return justReleased('note_8k_6');
	private function get_NOTE_8K_7_R() return justReleased('note_8k_7');
	private function get_NOTE_8K_8_R() return justReleased('note_8k_8');

	// 9K
	private function get_NOTE_9K_1() return pressed('note_9k_1');
	private function get_NOTE_9K_2() return pressed('note_9k_2');
	private function get_NOTE_9K_3() return pressed('note_9k_3');
	private function get_NOTE_9K_4() return pressed('note_9k_4');
	private function get_NOTE_9K_5() return pressed('note_9k_5');
	private function get_NOTE_9K_6() return pressed('note_9k_6');
	private function get_NOTE_9K_7() return pressed('note_9k_7');
	private function get_NOTE_9K_8() return pressed('note_9k_8');
	private function get_NOTE_9K_9() return pressed('note_9k_9');

	private function get_NOTE_9K_1_R() return justReleased('note_9k_1');
	private function get_NOTE_9K_2_R() return justReleased('note_9k_2');
	private function get_NOTE_9K_3_R() return justReleased('note_9k_3');
	private function get_NOTE_9K_4_R() return justReleased('note_9k_4');
	private function get_NOTE_9K_5_R() return justReleased('note_9k_5');
	private function get_NOTE_9K_6_R() return justReleased('note_9k_6');
	private function get_NOTE_9K_7_R() return justReleased('note_9k_7');
	private function get_NOTE_9K_8_R() return justReleased('note_9k_8');
	private function get_NOTE_9K_9_R() return justReleased('note_9k_9');

	// 10K
	private function get_NOTE_10K_1() return pressed('note_10k_1');
	private function get_NOTE_10K_2() return pressed('note_10k_2');
	private function get_NOTE_10K_3() return pressed('note_10k_3');
	private function get_NOTE_10K_4() return pressed('note_10k_4');
	private function get_NOTE_10K_5() return pressed('note_10k_5');
	private function get_NOTE_10K_6() return pressed('note_10k_6');
	private function get_NOTE_10K_7() return pressed('note_10k_7');
	private function get_NOTE_10K_8() return pressed('note_10k_8');
	private function get_NOTE_10K_9() return pressed('note_10k_9');
	private function get_NOTE_10K_10() return pressed('note_10k_10');

	private function get_NOTE_10K_1_R() return justReleased('note_10k_1');
	private function get_NOTE_10K_2_R() return justReleased('note_10k_2');
	private function get_NOTE_10K_3_R() return justReleased('note_10k_3');
	private function get_NOTE_10K_4_R() return justReleased('note_10k_4');
	private function get_NOTE_10K_5_R() return justReleased('note_10k_5');
	private function get_NOTE_10K_6_R() return justReleased('note_10k_6');
	private function get_NOTE_10K_7_R() return justReleased('note_10k_7');
	private function get_NOTE_10K_8_R() return justReleased('note_10k_8');
	private function get_NOTE_10K_9_R() return justReleased('note_10k_9');
	private function get_NOTE_10K_10_R() return justReleased('note_10k_10');

	// 11K
	private function get_NOTE_11K_1() return pressed('note_11k_1');
	private function get_NOTE_11K_2() return pressed('note_11k_2');
	private function get_NOTE_11K_3() return pressed('note_11k_3');
	private function get_NOTE_11K_4() return pressed('note_11k_4');
	private function get_NOTE_11K_5() return pressed('note_11k_5');
	private function get_NOTE_11K_6() return pressed('note_11k_6');
	private function get_NOTE_11K_7() return pressed('note_11k_7');
	private function get_NOTE_11K_8() return pressed('note_11k_8');
	private function get_NOTE_11K_9() return pressed('note_11k_9');
	private function get_NOTE_11K_10() return pressed('note_11k_10');
	private function get_NOTE_11K_11() return pressed('note_11k_11');

	private function get_NOTE_11K_1_R() return justReleased('note_11k_1');
	private function get_NOTE_11K_2_R() return justReleased('note_11k_2');
	private function get_NOTE_11K_3_R() return justReleased('note_11k_3');
	private function get_NOTE_11K_4_R() return justReleased('note_11k_4');
	private function get_NOTE_11K_5_R() return justReleased('note_11k_5');
	private function get_NOTE_11K_6_R() return justReleased('note_11k_6');
	private function get_NOTE_11K_7_R() return justReleased('note_11k_7');
	private function get_NOTE_11K_8_R() return justReleased('note_11k_8');
	private function get_NOTE_11K_9_R() return justReleased('note_11k_9');
	private function get_NOTE_11K_10_R() return justReleased('note_11k_10');
	private function get_NOTE_11K_11_R() return justReleased('note_11k_11');

	// 12K
	private function get_NOTE_12K_1() return pressed('note_12k_1');
	private function get_NOTE_12K_2() return pressed('note_12k_2');
	private function get_NOTE_12K_3() return pressed('note_12k_3');
	private function get_NOTE_12K_4() return pressed('note_12k_4');
	private function get_NOTE_12K_5() return pressed('note_12k_5');
	private function get_NOTE_12K_6() return pressed('note_12k_6');
	private function get_NOTE_12K_7() return pressed('note_12k_7');
	private function get_NOTE_12K_8() return pressed('note_12k_8');
	private function get_NOTE_12K_9() return pressed('note_12k_9');
	private function get_NOTE_12K_10() return pressed('note_12k_10');
	private function get_NOTE_12K_11() return pressed('note_12k_11');
	private function get_NOTE_12K_12() return pressed('note_12k_12');

	private function get_NOTE_12K_1_R() return justReleased('note_12k_1');
	private function get_NOTE_12K_2_R() return justReleased('note_12k_2');
	private function get_NOTE_12K_3_R() return justReleased('note_12k_3');
	private function get_NOTE_12K_4_R() return justReleased('note_12k_4');
	private function get_NOTE_12K_5_R() return justReleased('note_12k_5');
	private function get_NOTE_12K_6_R() return justReleased('note_12k_6');
	private function get_NOTE_12K_7_R() return justReleased('note_12k_7');
	private function get_NOTE_12K_8_R() return justReleased('note_12k_8');
	private function get_NOTE_12K_9_R() return justReleased('note_12k_9');
	private function get_NOTE_12K_10_R() return justReleased('note_12k_10');
	private function get_NOTE_12K_11_R() return justReleased('note_12k_11');
	private function get_NOTE_12K_12_R() return justReleased('note_12k_12');

	// 13K
	private function get_NOTE_13K_1() return pressed('note_13k_1');
	private function get_NOTE_13K_2() return pressed('note_13k_2');
	private function get_NOTE_13K_3() return pressed('note_13k_3');
	private function get_NOTE_13K_4() return pressed('note_13k_4');
	private function get_NOTE_13K_5() return pressed('note_13k_5');
	private function get_NOTE_13K_6() return pressed('note_13k_6');
	private function get_NOTE_13K_7() return pressed('note_13k_7');
	private function get_NOTE_13K_8() return pressed('note_13k_8');
	private function get_NOTE_13K_9() return pressed('note_13k_9');
	private function get_NOTE_13K_10() return pressed('note_13k_10');
	private function get_NOTE_13K_11() return pressed('note_13k_11');
	private function get_NOTE_13K_12() return pressed('note_13k_12');
	private function get_NOTE_13K_13() return pressed('note_13k_13');

	private function get_NOTE_13K_1_R() return justReleased('note_13k_1');
	private function get_NOTE_13K_2_R() return justReleased('note_13k_2');
	private function get_NOTE_13K_3_R() return justReleased('note_13k_3');
	private function get_NOTE_13K_4_R() return justReleased('note_13k_4');
	private function get_NOTE_13K_5_R() return justReleased('note_13k_5');
	private function get_NOTE_13K_6_R() return justReleased('note_13k_6');
	private function get_NOTE_13K_7_R() return justReleased('note_13k_7');
	private function get_NOTE_13K_8_R() return justReleased('note_13k_8');
	private function get_NOTE_13K_9_R() return justReleased('note_13k_9');
	private function get_NOTE_13K_10_R() return justReleased('note_13k_10');
	private function get_NOTE_13K_11_R() return justReleased('note_13k_11');
	private function get_NOTE_13K_12_R() return justReleased('note_13k_12');
	private function get_NOTE_13K_13_R() return justReleased('note_13k_13');

	// 14K
	private function get_NOTE_14K_1() return pressed('note_14k_1');
	private function get_NOTE_14K_2() return pressed('note_14k_2');
	private function get_NOTE_14K_3() return pressed('note_14k_3');
	private function get_NOTE_14K_4() return pressed('note_14k_4');
	private function get_NOTE_14K_5() return pressed('note_14k_5');
	private function get_NOTE_14K_6() return pressed('note_14k_6');
	private function get_NOTE_14K_7() return pressed('note_14k_7');
	private function get_NOTE_14K_8() return pressed('note_14k_8');
	private function get_NOTE_14K_9() return pressed('note_14k_9');
	private function get_NOTE_14K_10() return pressed('note_14k_10');
	private function get_NOTE_14K_11() return pressed('note_14k_11');
	private function get_NOTE_14K_12() return pressed('note_14k_12');
	private function get_NOTE_14K_13() return pressed('note_14k_13');
	private function get_NOTE_14K_14() return pressed('note_14k_14');

	private function get_NOTE_14K_1_R() return justReleased('note_14k_1');
	private function get_NOTE_14K_2_R() return justReleased('note_14k_2');
	private function get_NOTE_14K_3_R() return justReleased('note_14k_3');
	private function get_NOTE_14K_4_R() return justReleased('note_14k_4');
	private function get_NOTE_14K_5_R() return justReleased('note_14k_5');
	private function get_NOTE_14K_6_R() return justReleased('note_14k_6');
	private function get_NOTE_14K_7_R() return justReleased('note_14k_7');
	private function get_NOTE_14K_8_R() return justReleased('note_14k_8');
	private function get_NOTE_14K_9_R() return justReleased('note_14k_9');
	private function get_NOTE_14K_10_R() return justReleased('note_14k_10');
	private function get_NOTE_14K_11_R() return justReleased('note_14k_11');
	private function get_NOTE_14K_12_R() return justReleased('note_14k_12');
	private function get_NOTE_14K_13_R() return justReleased('note_14k_13');
	private function get_NOTE_14K_14_R() return justReleased('note_14k_14');

	// 15K
	private function get_NOTE_15K_1() return pressed('note_15k_1');
	private function get_NOTE_15K_2() return pressed('note_15k_2');
	private function get_NOTE_15K_3() return pressed('note_15k_3');
	private function get_NOTE_15K_4() return pressed('note_15k_4');
	private function get_NOTE_15K_5() return pressed('note_15k_5');
	private function get_NOTE_15K_6() return pressed('note_15k_6');
	private function get_NOTE_15K_7() return pressed('note_15k_7');
	private function get_NOTE_15K_8() return pressed('note_15k_8');
	private function get_NOTE_15K_9() return pressed('note_15k_9');
	private function get_NOTE_15K_10() return pressed('note_15k_10');
	private function get_NOTE_15K_11() return pressed('note_15k_11');
	private function get_NOTE_15K_12() return pressed('note_15k_12');
	private function get_NOTE_15K_13() return pressed('note_15k_13');
	private function get_NOTE_15K_14() return pressed('note_15k_14');
	private function get_NOTE_15K_15() return pressed('note_15k_15');

	private function get_NOTE_15K_1_R() return justReleased('note_15k_1');
	private function get_NOTE_15K_2_R() return justReleased('note_15k_2');
	private function get_NOTE_15K_3_R() return justReleased('note_15k_3');
	private function get_NOTE_15K_4_R() return justReleased('note_15k_4');
	private function get_NOTE_15K_5_R() return justReleased('note_15k_5');
	private function get_NOTE_15K_6_R() return justReleased('note_15k_6');
	private function get_NOTE_15K_7_R() return justReleased('note_15k_7');
	private function get_NOTE_15K_8_R() return justReleased('note_15k_8');
	private function get_NOTE_15K_9_R() return justReleased('note_15k_9');
	private function get_NOTE_15K_10_R() return justReleased('note_15k_10');
	private function get_NOTE_15K_11_R() return justReleased('note_15k_11');
	private function get_NOTE_15K_12_R() return justReleased('note_15k_12');
	private function get_NOTE_15K_13_R() return justReleased('note_15k_13');
	private function get_NOTE_15K_14_R() return justReleased('note_15k_14');
	private function get_NOTE_15K_15_R() return justReleased('note_15k_15');

	// 16K
	private function get_NOTE_16K_1() return pressed('note_16k_1');
	private function get_NOTE_16K_2() return pressed('note_16k_2');
	private function get_NOTE_16K_3() return pressed('note_16k_3');
	private function get_NOTE_16K_4() return pressed('note_16k_4');
	private function get_NOTE_16K_5() return pressed('note_16k_5');
	private function get_NOTE_16K_6() return pressed('note_16k_6');
	private function get_NOTE_16K_7() return pressed('note_16k_7');
	private function get_NOTE_16K_8() return pressed('note_16k_8');
	private function get_NOTE_16K_9() return pressed('note_16k_9');
	private function get_NOTE_16K_10() return pressed('note_16k_10');
	private function get_NOTE_16K_11() return pressed('note_16k_11');
	private function get_NOTE_16K_12() return pressed('note_16k_12');
	private function get_NOTE_16K_13() return pressed('note_16k_13');
	private function get_NOTE_16K_14() return pressed('note_16k_14');
	private function get_NOTE_16K_15() return pressed('note_16k_15');
	private function get_NOTE_16K_16() return pressed('note_16k_16');

	private function get_NOTE_16K_1_R() return justReleased('note_16k_1');
	private function get_NOTE_16K_2_R() return justReleased('note_16k_2');
	private function get_NOTE_16K_3_R() return justReleased('note_16k_3');
	private function get_NOTE_16K_4_R() return justReleased('note_16k_4');
	private function get_NOTE_16K_5_R() return justReleased('note_16k_5');
	private function get_NOTE_16K_6_R() return justReleased('note_16k_6');
	private function get_NOTE_16K_7_R() return justReleased('note_16k_7');
	private function get_NOTE_16K_8_R() return justReleased('note_16k_8');
	private function get_NOTE_16K_9_R() return justReleased('note_16k_9');
	private function get_NOTE_16K_10_R() return justReleased('note_16k_10');
	private function get_NOTE_16K_11_R() return justReleased('note_16k_11');
	private function get_NOTE_16K_12_R() return justReleased('note_16k_12');
	private function get_NOTE_16K_13_R() return justReleased('note_16k_13');
	private function get_NOTE_16K_14_R() return justReleased('note_16k_14');
	private function get_NOTE_16K_15_R() return justReleased('note_16k_15');
	private function get_NOTE_16K_16_R() return justReleased('note_16k_16');

	// Pressed buttons (others)
	public var ACCEPT(get, never):Bool;
	public var BACK(get, never):Bool;
	public var PAUSE(get, never):Bool;
	public var RESET(get, never):Bool;
	private function get_ACCEPT() return justPressed('accept');
	private function get_BACK() return justPressed('back');
	private function get_PAUSE() return justPressed('pause');
	private function get_RESET() return justPressed('reset');

	//Gamepad & Keyboard stuff
	public var keyboardBinds:Map<String, Array<FlxKey>>;
	public var gamepadBinds:Map<String, Array<FlxGamepadInputID>>;
	public function justPressed(key:String)
	{
		var result:Bool = (FlxG.keys.anyJustPressed(keyboardBinds[key]) == true);
		if(result) controllerMode = false;

		return result || _myGamepadJustPressed(gamepadBinds[key]) == true;
	}

	public function pressed(key:String)
	{
		var result:Bool = (FlxG.keys.anyPressed(keyboardBinds[key]) == true);
		if(result) controllerMode = false;

		return result || _myGamepadPressed(gamepadBinds[key]) == true;
	}

	public function justReleased(key:String)
	{
		var result:Bool = (FlxG.keys.anyJustReleased(keyboardBinds[key]) == true);
		if(result) controllerMode = false;

		return result || _myGamepadJustReleased(gamepadBinds[key]) == true;
	}

	public function justPressedKeyIndex(key:String, index:Int):Bool
	{
		var keys:Array<FlxKey> = keyboardBinds[key];
		if(keys == null || index < 0 || index >= keys.length) return false;
		var result:Bool = (FlxG.keys.checkStatus(keys[index], JUST_PRESSED) == true);
		if(result) controllerMode = false;

		return result || _myGamepadJustPressedIndex(gamepadBinds[key], index) == true;
	}

	public function pressedKeyIndex(key:String, index:Int):Bool
	{
		var keys:Array<FlxKey> = keyboardBinds[key];
		if(keys == null || index < 0 || index >= keys.length) return false;
		var result:Bool = (FlxG.keys.checkStatus(keys[index], PRESSED) == true);
		if(result) controllerMode = false;

		return result || _myGamepadPressedIndex(gamepadBinds[key], index) == true;
	}

	public function justReleasedKeyIndex(key:String, index:Int):Bool
	{
		var keys:Array<FlxKey> = keyboardBinds[key];
		if(keys == null || index < 0 || index >= keys.length) return false;
		var result:Bool = (FlxG.keys.checkStatus(keys[index], JUST_RELEASED) == true);
		if(result) controllerMode = false;

		return result || _myGamepadJustReleasedIndex(gamepadBinds[key], index) == true;
	}

	public var controllerMode:Bool = false;
	private function _myGamepadJustPressed(keys:Array<FlxGamepadInputID>):Bool
	{
		if(keys != null)
		{
			for (key in keys)
			{
				if (FlxG.gamepads.anyJustPressed(key) == true)
				{
					controllerMode = true;
					return true;
				}
			}
		}
		return false;
	}
	private function _myGamepadJustPressedIndex(keys:Array<FlxGamepadInputID>, index:Int):Bool
	{
		if(keys != null && index >= 0 && index < keys.length)
		{
			if (FlxG.gamepads.anyJustPressed(keys[index]) == true)
			{
				controllerMode = true;
				return true;
			}
		}
		return false;
	}
	private function _myGamepadPressed(keys:Array<FlxGamepadInputID>):Bool
	{
		if(keys != null)
		{
			for (key in keys)
			{
				if (FlxG.gamepads.anyPressed(key) == true)
				{
					controllerMode = true;
					return true;
				}
			}
		}
		return false;
	}
	private function _myGamepadPressedIndex(keys:Array<FlxGamepadInputID>, index:Int):Bool
	{
		if(keys != null && index >= 0 && index < keys.length)
		{
			if (FlxG.gamepads.anyPressed(keys[index]) == true)
			{
				controllerMode = true;
				return true;
			}
		}
		return false;
	}
	private function _myGamepadJustReleased(keys:Array<FlxGamepadInputID>):Bool
	{
		if(keys != null)
		{
			for (key in keys)
			{
				if (FlxG.gamepads.anyJustReleased(key) == true)
				{
					controllerMode = true;
					return true;
				}
			}
		}
		return false;
	}
	private function _myGamepadJustReleasedIndex(keys:Array<FlxGamepadInputID>, index:Int):Bool
	{
		if(keys != null && index >= 0 && index < keys.length)
		{
			if (FlxG.gamepads.anyJustReleased(keys[index]) == true)
			{
				controllerMode = true;
				return true;
			}
		}
		return false;
	}

	// IGNORE THESE
	public static var instance:Controls;
	public function new()
	{
		keyboardBinds = ClientPrefs.keyBinds;
		gamepadBinds = ClientPrefs.gamepadBinds;
		
		// 动态添加多键位映射
		var keyCount = PlayState.SONG != null ? objects.Note.getColumnsPerPlayer(PlayState.SONG) : 4;
		for (k in 1...17) // 5K 到 16K
		{
			if (k > keyCount) break;
			for (i in 1...k+1)
			{
				var keyName = 'note_${k}k_$i';
				if (!keyboardBinds.exists(keyName))
				{
				// 直接从已存在的 keyBinds 中获取
				var keyName = 'note_${k}k_$i';
					if (!keyboardBinds.exists(keyName))
					{
						// 如果不存在，从 ClientPrefs.keyBinds 中获取
						var defaultKey = ClientPrefs.keyBinds.get(keyName);
						if (defaultKey != null)
						{
							keyboardBinds.set(keyName, defaultKey.copy());
						}
					}
				}
			}
		}
	}
}