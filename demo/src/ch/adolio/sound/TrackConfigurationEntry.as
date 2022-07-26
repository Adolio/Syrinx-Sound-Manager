// =================================================================================================
//
//	Syrinx - Sound Manager
//	Copyright (c) 2019 Aurelien Da Campo (Adolio), All Rights Reserved.
//
//	This program is free software. You can redistribute and/or modify it
//	in accordance with the terms of the accompanying license agreement.
//
// =================================================================================================

package ch.adolio.sound
{
	import ch.adolio.sound.TrackConfiguration;
	import feathers.controls.Button;
	import feathers.controls.Label;
	import feathers.controls.LayoutGroup;
	import feathers.controls.NumericStepper;
	import feathers.controls.Slider;
	import feathers.controls.TextInput;
	import feathers.layout.HorizontalLayout;
	import starling.core.Starling;
	import starling.display.Quad;
	import starling.display.Sprite;
	import starling.events.Event;

	public class TrackConfigurationEntry extends Sprite
	{
		// Core references
		private var _trackConfiguration:TrackConfiguration;
		private var _soundTest:SoundManagerTest;

		// configuration
		private var _soundTypeLabel:Label;
		private var _baseVolumeSlider:Slider;
		private var _soundLength:Label;
		private var _trimStartTextInput:TextInput;
		private var _trimEndTextInput:TextInput;
		private var _trimButton:Button;

		// control
		private var _loopStepper:NumericStepper;
		private var _startPositionTextInput:TextInput;
		//private var _startVolumeSlider:Slider; // TODO
		private var _playButton:Button;
		private var _unregisterButton:Button;

		public function TrackConfigurationEntry(trackConfiguration:TrackConfiguration, soundTest:SoundManagerTest)
		{
			_trackConfiguration = trackConfiguration;
			_soundTest = soundTest;

			// background
			var quad:Quad = new Quad(Starling.current.stage.stageWidth, 30, 0xffffff);
			quad.alpha = 0.6;
			addChild(quad);

			// horizontal layout
			var layout:HorizontalLayout = new HorizontalLayout();
			layout.padding = 2;
			layout.gap = 4;
			var container:LayoutGroup = new LayoutGroup();
			container.layout = layout;
			container.width = quad.width;
			container.height = quad.height;
			this.addChild(container);

			// sound label
			_soundTypeLabel = new Label();
			_soundTypeLabel.width = 160;
			_soundTypeLabel.height = quad.height - (layout.paddingTop + layout.paddingBottom);
			_soundTypeLabel.text = _trackConfiguration.type;
			container.addChild(_soundTypeLabel);

			// base volume
			_baseVolumeSlider = new Slider();
			_baseVolumeSlider.minimum = 0;
			_baseVolumeSlider.maximum = 1.0;
			_baseVolumeSlider.step = 0.05;
			_baseVolumeSlider.width = 80;
			_baseVolumeSlider.value = _trackConfiguration.baseVolume;
			container.addChild(_baseVolumeSlider);
			_baseVolumeSlider.addEventListener(Event.CHANGE, onBaseVolumeChanged);

			// sound length in ms
			_soundLength = new Label();
			_soundLength.width = 80;
			_soundLength.text = (Math.round(_trackConfiguration.track.length * 100) / 100) + "";
			container.addChild(_soundLength);

			// Trim start text input
			_trimStartTextInput = new TextInput();
			_trimStartTextInput.width = 80;
			_trimStartTextInput.text = _trackConfiguration.trimStartDuration.toString();
			container.addChild(_trimStartTextInput);
			_trimStartTextInput.addEventListener(Event.CHANGE, onTrimStartDurationChanged);

			// Trim end text input
			_trimEndTextInput = new TextInput();
			_trimEndTextInput.width = 80;
			_trimEndTextInput.text = _trackConfiguration.trimEndDuration.toString();
			container.addChild(_trimEndTextInput);
			_trimEndTextInput.addEventListener(Event.CHANGE, onTrimEndDurationChanged);

			// Auto detect trimming values
			_trimButton = new Button();
			_trimButton.label = "Auto Trim";
			_trimButton.width = 60;
			_trimButton.addEventListener(Event.TRIGGERED, onTrimButtonTriggered);
			container.addChild(_trimButton);

			//-----------------------------------------------------------------
			//-- Controls
			//-----------------------------------------------------------------

			// Separator
			var separator:Quad = new Quad(20, 1);
			separator.alpha = 0;
			container.addChild(separator);

			// Loop input
			_loopStepper = new NumericStepper();
			_loopStepper.minimum = -1;
			_loopStepper.maximum = 100;
			_loopStepper.step = 1;
			_loopStepper.width = 80;
			container.addChild(_loopStepper);

			// Start position input
			_startPositionTextInput = new TextInput();
			_startPositionTextInput.width = 80;
			_startPositionTextInput.text = "0";
			container.addChild(_startPositionTextInput);

			// play button
			_playButton = new Button();
			_playButton.label = "Play";
			_playButton.width = 60;
			_playButton.addEventListener(Event.TRIGGERED, onPlayButtonTriggered);
			container.addChild(_playButton);

			// Separator
			separator = new Quad(20, 1);
			separator.alpha = 0;
			container.addChild(separator);

			// unregister button
			_unregisterButton = new Button();
			_unregisterButton.label = "X";
			_unregisterButton.addEventListener(Event.TRIGGERED, onUnregisterButtonTriggered);
			container.addChild(_unregisterButton);
		}

		private function onBaseVolumeChanged():void
		{
			_trackConfiguration.baseVolume = _baseVolumeSlider.value;
		}

		private function onTrimButtonTriggered():void
		{
			_trackConfiguration.findTrim();

			_trimStartTextInput.text = _trackConfiguration.trimStartDuration.toString(); // TODO silent!
			_trimEndTextInput.text = _trackConfiguration.trimEndDuration.toString(); // TODO silent!
		}

		private function onPlayButtonTriggered():void
		{
			_soundTest.playSound(_trackConfiguration.type, 0.5, parseInt(_startPositionTextInput.text), _loopStepper.value);
		}

		private function onUnregisterButtonTriggered():void
		{
			_soundTest.unregisterSound(_trackConfiguration);
		}

		private function onTrimStartDurationChanged(e:Event):void
		{
			try
			{
				_trackConfiguration.trimStartDuration = parseInt(_trimStartTextInput.text);
			}
			catch (e:ArgumentError)
			{
				trace("[Sound Configuration Entry] Cannot update trimming value. Error: " + e.message);
			}
		}

		private function onTrimEndDurationChanged(e:Event):void
		{
			try
			{
				_trackConfiguration.trimEndDuration = parseInt(_trimEndTextInput.text);
			}
			catch (e:ArgumentError)
			{
				trace("[Sound Configuration Entry] Cannot update trimming value. Error: " + e.message);
			}
		}

		public function get trackConfiguration():TrackConfiguration
		{
			return _trackConfiguration;
		}
	}
}