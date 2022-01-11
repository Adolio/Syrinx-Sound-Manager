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
	import flash.errors.IllegalOperationError;
	import flash.utils.Dictionary;
	import org.osflash.signals.Signal;

	/**
	 * Sound Manager.
	 *
	 * <p>The Sound Manager allows to play sounds & handles sound instances.</p>
	 *
	 * @author Aurelien Da Campo
	 */
	public class SoundManager
	{
		// Const
		public static const VERSION:String = "0.4";
		public static const MAX_CHANNELS:uint = 32; // Adobe AIR hard limit

		// Core
		private var _tracksByType:Dictionary = new Dictionary(); // Dictionary of tracks
		private var _soundInstances:Vector.<SoundInstance> = new Vector.<SoundInstance>();
		private var _maxChannelCapacity:uint = MAX_CHANNELS; // Maximum number of sound instances playing simultaneously. The hard limit from Adobe AIR is `MAX_CHANNELS` for all Sound Managers together.

		// Options
		private var _volume:Number = 1.0;

		// Signals
		public var trackRegistered:Signal = new Signal(TrackConfiguration);
		public var trackUnregistered:Signal = new Signal(TrackConfiguration);
		public var soundInstanceAdded:Signal = new Signal(SoundInstance);
		public var soundInstanceRemoved:Signal = new Signal(SoundInstance);

		// Debug
		private static const LOG_PREFIX:String = "[Sound Manager]";

		//---------------------------------------------------------------------
		//-- Sound Instance Management
		//---------------------------------------------------------------------

		/**
		 * Play a sound of a given registered type.
		 *
		 * @param type      The type
		 * @param volume    Volume of the sound at start
		 * @param startTime Time at which the sound will start (in ms)
		 * @param loops     Number of loops of the sound (0 = no loop, -1 = infinite looping)
		 * @return The sound instance of the newly created sound. <code>null</code> if no sound has been found.
		 */
		public function play(type:String, volume:Number = 1.0, startTime:Number = 0, loops:int = 0):SoundInstance
		{
			// Create the sound instance
			var si:SoundInstance = createSound(type);

			// Start playing
			si.play(volume, startTime, loops);

			return si;
		}

		/**
		 * Request sound instances by type attached to this manager.
		 */
		public function getSoundInstancesByType(type:String):Vector.<SoundInstance>
		{
			// Setup output list
			var instances:Vector.<SoundInstance> = new Vector.<SoundInstance>();

			// Look for all instances of the given type
			var si:SoundInstance;
			var length:int = _soundInstances.length;
			for (var i:int = 0; i < length; ++i)
			{
				si = _soundInstances[i];
				if (si.type == type)
					instances.push(si);
			}

			return instances;
		}

		/**
		 * Return the number of current sound instances.
		 */
		public function getSoundInstancesCount():uint
		{
			return _soundInstances.length;
		}

		/**
		 * Return the playing number of current sound instances.
		 */
		public function getPlayingSoundInstancesCount():uint
		{
			var count:uint = 0;
			var length:int = _soundInstances.length;
			for (var i:int = 0; i < length; ++i)
				if (_soundInstances[i].isPlaying)
					count++;

			return count;
		}

		/**
		 * Check if the sound manager has a sound instance of the given type.
		 */
		public function hasSoundInstancesOfType(type:String):Boolean
		{
			// Look for any instances of the given type
			var length:int = _soundInstances.length;
			for (var i:int = 0; i < length; ++i)
				if (_soundInstances[i].type == type)
					return true;

			return false;
		}

		public function getSoundInstances():Vector.<SoundInstance>
		{
			// Setup output list
			var instances:Vector.<SoundInstance> = new Vector.<SoundInstance>();

			var length:int = _soundInstances.length;
			for (var i:int = 0; i < length; ++i)
				instances.push(_soundInstances[i]);

			return instances;
		}

		/**
		 * Stop all sounds immediately.
		 */
		public function stopAll():void
		{
			var length:int = _soundInstances.length;
			for (var i:int = 0; i < length; ++i)
				_soundInstances[i].stop();
		}

		/**
		 * Destroy all sound instances.
		 *
		 * Sounds can be stopped before destruction if required.
		 */
		public function destroyAllSoundInstances(stopSoundBeforeDestroying:Boolean = true):void
		{
			while (_soundInstances.length > 0)
			{
				var si:SoundInstance = _soundInstances[0];

				// Stop sound instance
				if (stopSoundBeforeDestroying)
					si.stop();

				// Destroy sound instance
				si.destroy(); // This will automatically remove the instance from the list of sound instances
			}
		}

		//---------------------------------------------------------------------
		//-- Tracks Management
		//---------------------------------------------------------------------

		/**
		 * Register a new track.
		 *
		 * <p>
		 * If `trimStartDuration` is negative the system will automatically look for it by using the auto trimming feature.
		 * The `TrackConfiguration.trimDefaultSilenceThreshold` is then used for silence threshold.
		 * </p>
		 *
		 * <p>
		 * If `trimEndDuration` is negative the system will automatically look for it by using the auto trimming feature.
		 * The `TrackConfiguration.trimDefaultSilenceThreshold` is then used for silence threshold.
		 * </p>
		 */
		public function registerTrack(type:String, track:Track, trimStartDuration:Number = 0, trimEndDuration:Number = 0, sampling:uint = 2048):TrackConfiguration
		{
			// Prevent to register twice an sound
			if (hasTrackRegistered(type))
				throw new ArgumentError(LOG_PREFIX + " Sound type '" + type + "' is already registered.");

			// Add sound type
			var trackConfig:TrackConfiguration = new TrackConfiguration(track, type, trimStartDuration, trimEndDuration, sampling);
			_tracksByType[type] = trackConfig;

			// Emit event
			trackRegistered.dispatch(trackConfig);

			// Return the config
			return trackConfig;
		}

		/**
		 * Unregister a track.
		 */
		public function unregisterTrack(type:String):void
		{
			// Prevent deleting unregistered track
			if (!hasTrackRegistered(type))
				return;

			// Keep a reference of the config before deleting it
			var trackConfig:TrackConfiguration = _tracksByType[type];

			// Delete entry
			delete _tracksByType[type];

			// Destroy the configuration
			trackConfig.destroy();

			// Emit event
			trackUnregistered.dispatch(trackConfig);
		}

		/**
		 * Get list of registered tracks
		 */
		public function getRegisterTracks():Vector.<TrackConfiguration>
		{
			var tracksConfig:Vector.<TrackConfiguration> = new Vector.<TrackConfiguration>();
			for each (var trackConfig:TrackConfiguration in _tracksByType)
				tracksConfig.push(trackConfig);
			return tracksConfig;
		}

		/**
		 * Check if a track is already registered.
		 */
		public function hasTrackRegistered(type:String):Boolean
		{
			return _tracksByType[type] != undefined;
		}

		//---------------------------------------------------------------------
		//-- Internal
		//---------------------------------------------------------------------

		private function onSoundDestroyed(si:SoundInstance):void
		{
			// Look for the sound
			var index:int = _soundInstances.indexOf(si);
			if (index != -1)
			{
				// Remove from instances
				_soundInstances.removeAt(index);

				// Emit event
				soundInstanceRemoved.dispatch(si);
			}
		}

		private function onSoundCompleted(si:SoundInstance):void
		{
			// Remove sound instance
			if (si.manager == this)
				si.manager = null; // This will automatically trigger the unregistration
			else
				trace(LOG_PREFIX + " There is a Sound Manager inconsistency.");
		}

		/**
		 * Create a sound instance of a given type.
		 */
		private function createSound(type:String):SoundInstance
		{
			// Unknown sound type
			if (_tracksByType[type] == undefined)
				throw new IllegalOperationError(LOG_PREFIX + " Sound type not registered: " + type);

			// Sound instance will automatically register to the sound manager
			return new SoundInstance(_tracksByType[type], this);
		}

		/**
		 * Remove a sound instance from the list of sound.
		 */
		internal function removeSoundInstance(si:SoundInstance, destroy:Boolean = false):void
		{
			// Look for the sound instance
			var index:int = _soundInstances.indexOf(si);
			if (index != -1)
			{
				// Stop listening to sound completion
				if (!si.isDestroyed)
				{
					si.destroyed.remove(onSoundDestroyed);
					si.completed.remove(onSoundCompleted);
				}

				// Remove from instances
				_soundInstances.removeAt(index);

				// Emit event
				soundInstanceRemoved.dispatch(si);

				// Destroy if asked and not destroyed yet
				if (!si.isDestroyed && destroy)
					si.destroy();
			}
			else
			{
				trace(LOG_PREFIX + " Sound instance not found! Cannot remove.");
			}
		}

		/**
		 * Add a sound instance to the list of sound.
		 */
		internal function addSoundInstance(si:SoundInstance):void
		{
			// Prevent adding an already added sound instance
			if (_soundInstances.indexOf(si) != -1)
				throw new ArgumentError(LOG_PREFIX + " Cannot add twice the same sound instance.");

			// Add the instance
			_soundInstances.push(si);

			// Listen to sound events
			si.completed.add(onSoundCompleted);
			si.destroyed.add(onSoundDestroyed);

			// Update (mixed) volume
			si.volume = si.volume;

			// Emit event
			soundInstanceAdded.dispatch(si);
		}

		//---------------------------------------------------------------------
		//-- Master Volume
		//---------------------------------------------------------------------

		/**
		 * Get the current master volume.
		 */
		public function get volume():Number
		{
			return _volume;
		}

		/**
		 * Set the current master volume.
		 *
		 * This will update all contained sound instances.
		 */
		public function set volume(value:Number):void
		{
			_volume = value;

			// Update (mixed) volume of all the sound instances
			var si:SoundInstance;
			var length:int = _soundInstances.length;
			for (var i:int = 0; i < length; ++i)
			{
				si = _soundInstances[i];
				si.volume = si.volume; // Force volume update from manager
			}
		}

		//---------------------------------------------------------------------
		//-- Max Channel Capacity
		//---------------------------------------------------------------------

		/**
		 * Get the maximum possible number of sound instances playing simultaneously for this Sound Manager.
		 */
		public function get maxChannelCapacity():uint
		{
			return _maxChannelCapacity;
		}

		/**
		 * Set the maximum possible number of sound instances playing simultaneously for this Sound Manager.
		 *
		 * <p>
		 * Note: the hard limit from Adobe AIR is MAX_CHANNELS (32) for all Sound Managers together.
		 * </p>
		 */
		public function set maxChannelCapacity(value:uint):void
		{
			if (value > MAX_CHANNELS)
				throw new ArgumentError(LOG_PREFIX + " Invalid argument. Max channel capacity cannot be bigger than " + MAX_CHANNELS + ". This is an hard limit from Adobe AIR.");

			_maxChannelCapacity = value;
		}
	}
}