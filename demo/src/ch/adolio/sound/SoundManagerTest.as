// =================================================================================================
//
//	Syrinx - Sound Manager
//	Copyright (c) 2019-2026 Aurelien Da Campo (Adolio), All Rights Reserved.
//
//	This program is free software. You can redistribute and/or modify it
//	in accordance with the terms of the accompanying license agreement.
//
// =================================================================================================

package ch.adolio.sound
{
	import ch.adolio.sound.Mp3Track;
	import ch.adolio.sound.SoundInstance;
	import ch.adolio.sound.SoundManager;
	import ch.adolio.sound.TrackConfiguration;
	import ch.adolio.sound.WavTrack;
	import feathers.controls.Button;
	import feathers.controls.Label;
	import feathers.controls.ScrollBarDisplayMode;
	import feathers.controls.ScrollContainer;
	import feathers.controls.Slider;
	import feathers.layout.VerticalLayout;
	import flash.events.Event;
	import flash.events.IOErrorEvent;
	import flash.filesystem.File;
	import flash.filesystem.FileMode;
	import flash.filesystem.FileStream;
	import flash.media.Sound;
	import flash.net.FileFilter;
	import flash.net.URLRequest;
	import flash.utils.ByteArray;
	import flash.utils.Dictionary;
	import starling.core.Starling;
	import starling.display.Sprite;
	import starling.events.Event;

	public class SoundManagerTest extends Sprite
	{
		// Sound Manager
		private var _sndMgr:SoundManager;
		private var _masterVolumeSlider:Slider;

		// Loading
		private var _loadMp3SoundButton:Button;
		private var _loadWavSoundButton:Button;
		private var _currentFileRef:File;
		private var _loadingMp3Names:Dictionary = new Dictionary(); // File name by sound being loaded

		// Registered sounds
		private var _trackConfigurationEntries:Vector.<TrackConfigurationEntry> = new Vector.<TrackConfigurationEntry>();
		private var _registeredTrackLabel:Label;
		private var _trackConfigurationEntriesContainer:ScrollContainer;
		private var _soundConfigurationEntryHeader:TrackConfigurationEntryHeader;

		// Running sounds
		private var _soundInstanceEntries:Vector.<SoundInstanceEntry> = new Vector.<SoundInstanceEntry>();
		private var _runningSoundsLabel:Label;
		private var _soundInstanceEntriesContainer:ScrollContainer;
		private var _soundInstanceEntryHeader:SoundInstanceEntryHeader;

		// Pool
		private var _poolInfoLabel:Label;

		// Embedded sounds source
		[Embed(source = "../../../../media/sounds/piano_IEEE32_mono_44100.wav", mimeType="application/octet-stream")] public static const piano_IEEE32_mono_44100:Class;
		[Embed(source = "../../../../media/sounds/piano_IEEE32_stereo_44100.wav", mimeType="application/octet-stream")] public static const piano_IEEE32_stereo_44100:Class;
		[Embed(source = "../../../../media/sounds/piano_PCM16_mono_44100.wav", mimeType="application/octet-stream")] public static const piano_PCM16_mono_44100:Class;
		[Embed(source = "../../../../media/sounds/piano_PCM16_stereo_44100.wav", mimeType="application/octet-stream")] public static const piano_PCM16_stereo_44100:Class;
		[Embed(source = "../../../../media/sounds/piano_MP3_mono_44100.mp3")] public static const piano_MP3_mono_44100:Class;
		[Embed(source = "../../../../media/sounds/piano_MP3_stereo_44100.mp3")] public static const piano_MP3_stereo_44100:Class;

		public function SoundManagerTest()
		{
			super();

			// UI optimization when doing nothing
			Starling.current.skipUnchangedFrames = true;

			// Create sound manager
			_sndMgr = new SoundManager();
			//_sndMgr.maxChannelCapacity = 3; // Limit number of simultaneous playing sounds
			_sndMgr.isPoolingEnabled = true; // Enable pooling

			// Register to events
			_sndMgr.trackRegistered.add(onTrackRegisteredToManager);
			_sndMgr.trackUnregistered.add(onTrackUnregisteredFromManager);
			_sndMgr.soundInstanceAdded.add(onSoundInstanceAddedToManager);
			_sndMgr.soundInstanceRemoved.add(onSoundInstanceRemoveFromManager);
			_sndMgr.soundInstanceReleasedToPool.add(onSoundInstanceReleasedToPool);

			// Setting up the UI
			setupUI();

			// Register sounds
			var predecodeWav:Boolean = false;
			_sndMgr.registerTrack("piano_IEEE32_mono_44100", new WavTrack(new piano_IEEE32_mono_44100(), predecodeWav));
			_sndMgr.registerTrack("piano_IEEE32_stereo_44100", new WavTrack(new piano_IEEE32_stereo_44100(), predecodeWav));
			_sndMgr.registerTrack("piano_PCM16_mono_44100", new WavTrack(new piano_PCM16_mono_44100(), predecodeWav));
			_sndMgr.registerTrack("piano_PCM16_stereo_44100", new WavTrack(new piano_PCM16_stereo_44100(), predecodeWav));
			_sndMgr.registerTrack("piano_MP3_mono_44100", new Mp3Track(new piano_MP3_mono_44100()));
			_sndMgr.registerTrack("piano_MP3_stereo_44100", new Mp3Track(new piano_MP3_stereo_44100()));
		}

		private function setupUI():void
		{
			//-----------------------------------------------------------------
			//-- Title
			//-----------------------------------------------------------------

			// Volume label
			var titleLable:Label = new Label();
			titleLable.text = "Syrinx - Sound Manager Demo";
			titleLable.x = 8;
			titleLable.y = 16;
			titleLable.validate();
			addChild(titleLable);

			//-----------------------------------------------------------------
			//-- Sound Manager
			//-----------------------------------------------------------------

			// Volume label
			var masterVolumeLabel:Label = new Label();
			masterVolumeLabel.text = "Master volume";
			masterVolumeLabel.x = 8;
			masterVolumeLabel.y = titleLable.y + titleLable.height + 16;
			masterVolumeLabel.validate();
			addChild(masterVolumeLabel);

			// Volume slider
			_masterVolumeSlider = new Slider();
			_masterVolumeSlider.minimum = 0;
			_masterVolumeSlider.maximum = 1.0;
			_masterVolumeSlider.value = 0.5;
			_masterVolumeSlider.x = masterVolumeLabel.x + masterVolumeLabel.width + 8;
			_masterVolumeSlider.y = masterVolumeLabel.y;
			_masterVolumeSlider.addEventListener(starling.events.Event.CHANGE, onMasterVolumeValueChanged);
			addChild(_masterVolumeSlider);

			// Apply the initial master volume
			_sndMgr.volume = _masterVolumeSlider.value;

			//-----------------------------------------------------------------
			//-- Registered tracks
			//-----------------------------------------------------------------

			// Registered sounds label
			_registeredTrackLabel = new Label();
			_registeredTrackLabel.text = "Registered tracks";
			_registeredTrackLabel.x = 8;
			_registeredTrackLabel.y = masterVolumeLabel.y + masterVolumeLabel.height + 16;
			_registeredTrackLabel.validate();
			addChild(_registeredTrackLabel);

			// Load MP3
			_loadMp3SoundButton = new Button();
			_loadMp3SoundButton.label = "Load MP3";
			_loadMp3SoundButton.validate();
			_loadMp3SoundButton.x = 16;
			_loadMp3SoundButton.y = _registeredTrackLabel.y + _registeredTrackLabel.height + 8;
			_loadMp3SoundButton.addEventListener(starling.events.Event.TRIGGERED, onLoadMp3SoundTriggered);
			addChild(_loadMp3SoundButton);

			// Load WAV
			_loadWavSoundButton = new Button();
			_loadWavSoundButton.label = "Load WAV";
			_loadWavSoundButton.validate();
			_loadWavSoundButton.x = _loadMp3SoundButton.x + _loadMp3SoundButton.width + 8;
			_loadWavSoundButton.y = _registeredTrackLabel.y + _registeredTrackLabel.height + 8;
			_loadWavSoundButton.addEventListener(starling.events.Event.TRIGGERED, onLoadWavSoundTriggered);
			addChild(_loadWavSoundButton);

			// Registered tracks
			var soundConfigurationEntriesLayout:VerticalLayout = new VerticalLayout();
			soundConfigurationEntriesLayout.gap = 1;
			_trackConfigurationEntriesContainer = new ScrollContainer();
			_trackConfigurationEntriesContainer.layout = soundConfigurationEntriesLayout;
			_trackConfigurationEntriesContainer.scrollBarDisplayMode = ScrollBarDisplayMode.FLOAT;
			_trackConfigurationEntriesContainer.x = 16;
			_trackConfigurationEntriesContainer.y = _loadMp3SoundButton.y + _loadMp3SoundButton.height + 8;
			_trackConfigurationEntriesContainer.width = Starling.current.stage.stageWidth;
			_trackConfigurationEntriesContainer.height = 240;
			addChild(_trackConfigurationEntriesContainer);

			// Setup header
			_soundConfigurationEntryHeader = new TrackConfigurationEntryHeader();
			_trackConfigurationEntriesContainer.addChild(_soundConfigurationEntryHeader);

			//-----------------------------------------------------------------
			//-- Running sounds
			//-----------------------------------------------------------------

			// Registered sounds label
			_runningSoundsLabel = new Label();
			_runningSoundsLabel.text = "Running sounds";
			_runningSoundsLabel.x = 8;
			_runningSoundsLabel.y = _trackConfigurationEntriesContainer.y + _trackConfigurationEntriesContainer.height + 8;
			_runningSoundsLabel.validate();
			addChild(_runningSoundsLabel);

			// Running sounds
			var soundInstanceEntriesLayout:VerticalLayout = new VerticalLayout();
			soundInstanceEntriesLayout.gap = 1;
			_soundInstanceEntriesContainer = new ScrollContainer();
			_soundInstanceEntriesContainer.layout = soundInstanceEntriesLayout;
			_soundInstanceEntriesContainer.scrollBarDisplayMode = ScrollBarDisplayMode.FLOAT;
			_soundInstanceEntriesContainer.x = 16;
			_soundInstanceEntriesContainer.y = _runningSoundsLabel.y + _runningSoundsLabel.height + 8;
			_soundInstanceEntriesContainer.width = Starling.current.stage.stageWidth;
			_soundInstanceEntriesContainer.height = 400;
			addChild(_soundInstanceEntriesContainer);

			// Setup header
			_soundInstanceEntryHeader = new SoundInstanceEntryHeader();
			_soundInstanceEntriesContainer.addChild(_soundInstanceEntryHeader);

			//-----------------------------------------------------------------
			//-- Pool info
			//-----------------------------------------------------------------

			_poolInfoLabel = new Label();
			_poolInfoLabel.text = "Placeholder text";
			_poolInfoLabel.validate();
			_poolInfoLabel.x = 8;
			_poolInfoLabel.y = Starling.current.stage.stageHeight - _poolInfoLabel.height - 8;
			addChild(_poolInfoLabel);

			updatePoolInfoLabel();
		}

		public function playSound(type:String, volume:Number = 1.0, startTime:Number = 0, loops:int = 0):SoundInstance
		{
			return _sndMgr.play(type, volume, startTime, loops);
		}

		public function unregisterSound(soundConfiguration:TrackConfiguration):void
		{
			_sndMgr.unregisterTrack(soundConfiguration.type);
		}

		public function updateRunningSoundsLabel():void
		{
			_runningSoundsLabel.text = "Running sounds (" + _sndMgr.getPlayingSoundInstancesCount() + "/" + _sndMgr.getSoundInstancesCount() + ")";
		}

		public function updatePoolInfoLabel():void
		{
			_poolInfoLabel.text = "Pool info (acquired: " + SoundInstancesPool.instance.acquiredCount + ", released: " + SoundInstancesPool.instance.releaseCount + ", available: " + SoundInstancesPool.instance.availableCount + ")";
		}

		private function onLoadMp3SoundTriggered(event:starling.events.Event):void
		{
			loadMp3SoundFromDisk();
		}

		private function onLoadWavSoundTriggered(event:starling.events.Event):void
		{
			loadWavSoundFromDisk();
		}

		private function onMasterVolumeValueChanged(event:starling.events.Event):void
		{
			_sndMgr.volume = _masterVolumeSlider.value;
		}

		private function onTrackRegisteredToManager(tc:TrackConfiguration):void
		{
			// Create entry & register sound
			var entry:TrackConfigurationEntry = new TrackConfigurationEntry(tc, this);
			_trackConfigurationEntriesContainer.addChild(entry);
			_trackConfigurationEntries.push(entry);

			// Update running tracks label
			_registeredTrackLabel.text = "Registered tracks (" + _sndMgr.getRegisteredTracks().length + ")";
		}

		private function onTrackUnregisteredFromManager(tc:TrackConfiguration):void
		{
			// Remove completed sound instance entry
			for (var i:int = 0; i < _trackConfigurationEntries.length; ++i)
			{
				if (_trackConfigurationEntries[i].trackConfiguration == tc)
				{
					_trackConfigurationEntriesContainer.removeChild(_trackConfigurationEntries[i]);
					_trackConfigurationEntries.removeAt(i);
					break;
				}
			}

			_registeredTrackLabel.text = "Registered tracks (" + _sndMgr.getRegisteredTracks().length + ")";
		}

		private function onSoundInstanceAddedToManager(si:SoundInstance):void
		{
			// Create entry & register sound
			var entry:SoundInstanceEntry = new SoundInstanceEntry(si);
			entry.playStatusUpdated.add(onSoundInstanceEntryPlayStatusUpdated);
			_soundInstanceEntriesContainer.addChild(entry);
			_soundInstanceEntries.push(entry);

			// Update running sounds label
			updateRunningSoundsLabel();
			updatePoolInfoLabel();
		}

		private function onSoundInstanceEntryPlayStatusUpdated(entry:SoundInstanceEntry):void
		{
			// Update running sounds label
			updateRunningSoundsLabel();
		}

		private function onSoundInstanceRemoveFromManager(si:SoundInstance):void
		{
			removeEntryForSoundInstance(si);
		}

		private function onSoundInstanceReleasedToPool(si:SoundInstance, pool:SoundInstancesPool):void
		{
			removeEntryForSoundInstance(si);
		}

		private function removeEntryForSoundInstance(si:SoundInstance):void
		{
			// Find & remove sound instance entry
			for (var i:int = 0; i < _soundInstanceEntries.length; ++i)
			{
				var entry:SoundInstanceEntry = _soundInstanceEntries[i];
				if (entry.soundInstance == si)
				{
					// Remove from lists & dispose: the entry stops following its sound instance
					_soundInstanceEntries.removeAt(i);
					_soundInstanceEntriesContainer.removeChild(entry, true);

					// No need to look for more entries
					break;
				}
			}

			// Update labels
			updateRunningSoundsLabel();
			updatePoolInfoLabel();
		}

		//-----------------------------------------------------------------
		//-- MP3 File loading
		//-----------------------------------------------------------------

		private function loadMp3SoundFromDisk():void
		{
			_currentFileRef = new File();

			_currentFileRef.addEventListener(flash.events.Event.SELECT, onMp3FileSelected);
			_currentFileRef.addEventListener(flash.events.Event.CANCEL, onMp3FileSelectionCanceled);

			var imageFileTypes:FileFilter = new FileFilter("MP3 (*.mp3)", "*.mp3");
			_currentFileRef.browse([imageFileTypes]);
		}

		private function onMp3FileSelectionCanceled(event:flash.events.Event):void
		{
			_currentFileRef.removeEventListener(flash.events.Event.SELECT, onMp3FileSelected);
			_currentFileRef.removeEventListener(flash.events.Event.CANCEL, onMp3FileSelectionCanceled);

			_currentFileRef = null;
		}

		private function onMp3FileSelected(e:Object):void
		{
			_currentFileRef.removeEventListener(flash.events.Event.SELECT, onMp3FileSelected);
			_currentFileRef.removeEventListener(flash.events.Event.CANCEL, onMp3FileSelectionCanceled);

			// Load sound for path (another file may be selected before the loading ends)
			var sound:Sound = new Sound();
			_loadingMp3Names[sound] = _currentFileRef.name;
			sound.addEventListener(flash.events.Event.COMPLETE, onMp3SoundLoaded);
			sound.addEventListener(IOErrorEvent.IO_ERROR, onMp3SoundLoadingFailed);
			sound.load(new URLRequest(_currentFileRef.url));
		}

		private function onMp3SoundLoaded(event:flash.events.Event):void
		{
			var sound:Sound = event.target as Sound;
			var name:String = stopLoadingMp3Sound(sound);

			try
			{
				// Register loaded sound
				_sndMgr.registerTrack(name, new Mp3Track(sound));
			}
			catch (e:ArgumentError)
			{
				trace("[Sound Test] Couldn't register MP3 track. Error: " + e.message);
			}
		}

		private function onMp3SoundLoadingFailed(event:IOErrorEvent):void
		{
			var name:String = stopLoadingMp3Sound(event.target as Sound);
			trace("[Sound Test] Couldn't load MP3 file '" + name + "'. Error: " + event.text);
		}

		/**
		 * Stops listening to a sound being loaded & returns the name of its file.
		 */
		private function stopLoadingMp3Sound(sound:Sound):String
		{
			sound.removeEventListener(flash.events.Event.COMPLETE, onMp3SoundLoaded);
			sound.removeEventListener(IOErrorEvent.IO_ERROR, onMp3SoundLoadingFailed);

			var name:String = _loadingMp3Names[sound];
			delete _loadingMp3Names[sound];
			return name;
		}

		//-----------------------------------------------------------------
		//-- WAV File loading
		//-----------------------------------------------------------------

		private function loadWavSoundFromDisk():void
		{
			_currentFileRef = new File();

			_currentFileRef.addEventListener(flash.events.Event.SELECT, onWavFileSelected);
			_currentFileRef.addEventListener(flash.events.Event.CANCEL, onWavFileSelectionCanceled);

			var imageFileTypes:FileFilter = new FileFilter("WAV (*.wav)", "*.wav");
			_currentFileRef.browse([imageFileTypes]);
		}

		private function onWavFileSelectionCanceled(event:flash.events.Event):void
		{
			_currentFileRef.removeEventListener(flash.events.Event.SELECT, onWavFileSelected);
			_currentFileRef.removeEventListener(flash.events.Event.CANCEL, onWavFileSelectionCanceled);

			_currentFileRef = null;
		}

		private function onWavFileSelected(e:Object):void
		{
			_currentFileRef.removeEventListener(flash.events.Event.SELECT, onWavFileSelected);
			_currentFileRef.removeEventListener(flash.events.Event.CANCEL, onWavFileSelectionCanceled);

			// The file may be unreadable, invalid, in an unsupported format or already registered
			try
			{
				// Load sound for path
				var fileStream:FileStream = new FileStream();
				fileStream.open(_currentFileRef, FileMode.READ);
				var bytes:ByteArray = new ByteArray();
				fileStream.readBytes(bytes);
				fileStream.close();

				// Register loaded sound
				_sndMgr.registerTrack(_currentFileRef.name, new WavTrack(bytes));
			}
			catch (e:Error)
			{
				trace("[Sound Test] Couldn't register Wav track. Error: " + e.message);
			}
		}
	}
}