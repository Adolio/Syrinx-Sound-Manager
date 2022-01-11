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
	import ch.adolio.sound.SoundInstance;
	import feathers.controls.Button;
	import feathers.controls.Check;
	import feathers.controls.Label;
	import feathers.controls.LayoutGroup;
	import feathers.controls.Slider;
	import feathers.events.FeathersEventType;
	import feathers.layout.HorizontalLayout;
	import org.osflash.signals.Signal;
	import starling.animation.IAnimatable;
	import starling.core.Starling;
	import starling.display.Quad;
	import starling.display.Sprite;
	import starling.events.Event;

	public class SoundInstanceEntry extends Sprite implements IAnimatable
	{
		public var _soundInstance:SoundInstance;

		private var _soundNameLabel:Label;
		private var _pauseResumeButton:Button;
		private var _stopButton:Button;
		private var _destroyButton:Button;
		private var _positionSlider:Slider;
		private var _loopsLabel:Label;
		private var _volumeSlider:Slider;
		private var _muteCheck:Check;
		private var _panSlider:Slider;
		private var _pitchSlider:Slider;

		public var _isPositionSliderGrabbed:Object;
		public var _wasPlayingWhenGrabbed:Object;

		public var playStatusUpdated:Signal = new Signal(SoundInstanceEntry);

		public function SoundInstanceEntry(soundInstance:SoundInstance)
		{
			_soundInstance = soundInstance;
			_soundInstance.started.add(onSoundStartedToBePlayed);
			_soundInstance.paused.add(onSoundPaused);
			_soundInstance.resumed.add(onSoundResumed);
			_soundInstance.stopped.add(onSoundStopped);
			_soundInstance.completed.add(onSoundCompleted);
			_soundInstance.destroyed.add(onSoundDestroyed);

			// Background
			var quad:Quad = new Quad(Starling.current.stage.stageWidth, 30, 0xffffff);
			quad.alpha = 0.6;
			addChild(quad);

			// Horizontal layout
			var layout:HorizontalLayout = new HorizontalLayout();
			layout.padding = 5;
			layout.gap = 5;
			var container:LayoutGroup = new LayoutGroup();
			container.layout = layout;
			container.width = quad.width;
			container.height = quad.height;
			this.addChild(container);

			// Sound label
			_soundNameLabel = new Label();
			_soundNameLabel.width = 160;
			_soundNameLabel.text = "#" + _soundInstance.id + " (" + _soundInstance.type + ")";
			container.addChild(_soundNameLabel);

			// Position slider
			_positionSlider = new Slider();
			_positionSlider.minimum = 0;
			_positionSlider.maximum = 1.0;
			_positionSlider.value = 0;
			_positionSlider.width = 200;
			_positionSlider.liveDragging = false; // Only dispatch change event when releasing thumb
			container.addChild(_positionSlider);
			_positionSlider.addEventListener(Event.CHANGE, onPositionValueChanged);
			_positionSlider.addEventListener(FeathersEventType.BEGIN_INTERACTION, onPositionSliderSelected);
			_positionSlider.addEventListener(FeathersEventType.END_INTERACTION, onPositionSliderReleased);

			// Loops label
			_loopsLabel = new Label();
			_loopsLabel.width = 40;
			container.addChild(_loopsLabel);

			// Volume slider
			_volumeSlider = new Slider();
			_volumeSlider.minimum = 0;
			_volumeSlider.maximum = 1.0;
			_volumeSlider.value = _soundInstance.volume;
			_volumeSlider.width = 100;
			container.addChild(_volumeSlider);
			_volumeSlider.addEventListener(Event.CHANGE, onVolumeValueChanged);

			// Mute
			_muteCheck = new Check();
			_muteCheck.width = 30;
			container.addChild(_muteCheck);
			_muteCheck.addEventListener(Event.CHANGE, onMuteValueChanged);

			// Pan slider
			_panSlider = new Slider();
			_panSlider.minimum = -1.0;
			_panSlider.maximum = 1.0;
			_panSlider.value = _soundInstance.pan;
			_panSlider.width = 100;
			container.addChild(_panSlider);
			_panSlider.addEventListener(Event.CHANGE, onPanValueChanged);

			// Pitch
			_pitchSlider = new Slider();
			_pitchSlider.minimum = 0.5;
			_pitchSlider.maximum = 2.0;
			_pitchSlider.value = _soundInstance.pitch;
			_pitchSlider.width = 100;
			container.addChild(_pitchSlider);
			_pitchSlider.addEventListener(Event.CHANGE, onPitchValueChanged);

			// Pause / resume button
			_pauseResumeButton = new Button();
			updatePauseResumeButtonText();
			_pauseResumeButton.width = 60;
			_pauseResumeButton.addEventListener(Event.TRIGGERED, onPauseResumeButtonTriggered);
			container.addChild(_pauseResumeButton);

			// Stop button
			_stopButton = new Button();
			_stopButton.label = "Stop";
			_stopButton.width = 60;
			_stopButton.addEventListener(Event.TRIGGERED, onStopButtonTriggered);
			container.addChild(_stopButton);

			// Destroy button
			_destroyButton = new Button();
			_destroyButton.label = "X";
			_destroyButton.width = 60;
			_destroyButton.addEventListener(Event.TRIGGERED, onDestroyButtonTriggered);
			container.addChild(_destroyButton);

			Starling.current.juggler.add(this);

			// Initial update
			updatePosition();
			updateLoopingStatus();
		}

		public function get soundInstance():SoundInstance
		{
			return _soundInstance;
		}

		public function advanceTime(time:Number):void
		{
			// Do not update when the sound instance is paused
			if (_soundInstance.isPaused)
				return;

			// Do not update when slider is grabbed by user
			if (_isPositionSliderGrabbed)
				return;

			updatePosition();
			updateLoopingStatus();
		}

		private function onSoundStartedToBePlayed(si:SoundInstance):void
		{
			updatePauseResumeButtonText();

			// Enable / disable position slider according looping options
			_positionSlider.isEnabled = _soundInstance.loopsRemaining != -1;

			// Update UI volume
			_volumeSlider.value = _soundInstance.volume; // TODO Do it silently to avoid re-updating the value

			playStatusUpdated.dispatch(this);
		}

		private function onSoundPaused(si:SoundInstance):void
		{
			updatePauseResumeButtonText();

			playStatusUpdated.dispatch(this);
		}

		private function onSoundResumed(si:SoundInstance):void
		{
			updatePauseResumeButtonText();

			playStatusUpdated.dispatch(this);
		}

		private function onSoundStopped(si:SoundInstance):void
		{
			updatePauseResumeButtonText();
			updateLoopingStatus();

			playStatusUpdated.dispatch(this);
		}

		private function onSoundCompleted(si:SoundInstance):void
		{
			playStatusUpdated.dispatch(this);
		}

		private function onSoundDestroyed(si:SoundInstance):void
		{
			// Reset sound instance reference (no need to unsubscribe to events since the object is destroyed)
			_soundInstance = null;

			// Stop refreshing
			Starling.current.juggler.remove(this);
		}

		private function onPositionValueChanged(event:Event):void
		{
			_soundInstance.positionRatio = _positionSlider.value;
		}

		private function onPositionSliderSelected(event:Event):void
		{
			_isPositionSliderGrabbed = true;

			// Pause
			_wasPlayingWhenGrabbed = !_soundInstance.isPaused;
			if (!_soundInstance.isPaused)
				_soundInstance.pause();
		}

		private function onPositionSliderReleased(event:Event):void
		{
			_isPositionSliderGrabbed = false;

			// Reset back playing status
			if (_wasPlayingWhenGrabbed && !_soundInstance.isDestroyed)
				_soundInstance.resume();
		}

		private function onPauseResumeButtonTriggered():void
		{
			if (_soundInstance)
			{
				if (_soundInstance.isStarted)
				{
					// Resume
					if (_soundInstance.isPaused)
					{
						_soundInstance.resume();
					}
					// Pause
					else
					{
						_soundInstance.pause();
					}
				}
				else
				{
					// Play
					_soundInstance.play(_soundInstance.volume, _positionSlider.value * _soundInstance.totalLength, _soundInstance.loops);
				}
			}
		}

		private function updatePauseResumeButtonText():void
		{
			if (!_soundInstance)
				return;

			if (_soundInstance.isStarted)
			{
				if (_soundInstance.isPaused)
				{
					_pauseResumeButton.label = "Resume";
				}
				else
				{
					_pauseResumeButton.label = "Pause";
				}
			}
			else
			{
				_pauseResumeButton.label = "Play";
			}
		}

		private function onStopButtonTriggered():void
		{
			_soundInstance.stop();
		}

		private function onDestroyButtonTriggered():void
		{
			_soundInstance.destroy();
		}

		private function onVolumeValueChanged(event:Event):void
		{
			_soundInstance.volume = _volumeSlider.value;
		}

		private function onMuteValueChanged(event:Event):void
		{
			_soundInstance.isMuted = _muteCheck.isSelected;
		}

		private function onPanValueChanged(event:Event):void
		{
			_soundInstance.pan = _panSlider.value;
		}

		private function onPitchValueChanged(event:Event):void
		{
			_soundInstance.pitch = _pitchSlider.value;
		}

		private function updatePosition():void
		{
			_positionSlider.removeEventListener(Event.CHANGE, onPositionValueChanged);
			_positionSlider.value = _soundInstance.positionRatio;
			_positionSlider.addEventListener(Event.CHANGE, onPositionValueChanged);
		}

		private function updateLoopingStatus():void
		{
			// Do not update when the sound instance is paused
			if (_soundInstance.isPaused)
				return;

			// Update loops
			if (_soundInstance.loops == -1)
				_loopsLabel.text = "∞";
			else if (_soundInstance.loops == 0)
				_loopsLabel.text = "-";
			else
				_loopsLabel.text = _soundInstance.currentLoop + "/" + _soundInstance.loops;
		}
	}
}