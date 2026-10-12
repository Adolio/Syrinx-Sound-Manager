// =================================================================================================
//
//	Syrinx - Sound Manager
//	Copyright (c) 2019-2022 Aurelien Da Campo (Adolio), All Rights Reserved.
//
//	This program is free software. You can redistribute and/or modify it
//	in accordance with the terms of the accompanying license agreement.
//
// =================================================================================================

package ch.adolio.sound
{
	/**
	 * Sound instances pool.
	 *
	 * @author Aurelien Da Campo
	 */
	public class SoundInstancesPool
	{
		// Pool
		private var _pool:Vector.<SoundInstance> = new Vector.<SoundInstance>();

		// Singleton
		private static var _instance:SoundInstancesPool;

		// Stats
		private var _acquiredCount:uint = 0;
		private var _savedCount:uint = 0;
		private var _releaseCount:uint = 0;

		// Debug
		private static const LOG_PREFIX:String = "[Sound Instances Pool]";

		/**
		 * Singleton
		 */
		public static function get instance():SoundInstancesPool
		{
			if (!_instance)
				_instance = new SoundInstancesPool();

			return _instance;
		}

		/**
		 * Acquires a Sound Instance.
		 *
		 * Don't forget the release it afterwards.
		 *
		 * @param trackConfig The track configuration
		 * @param manager The manager to which the sound instance should be added
		 * @return a Sound Instance found from the pool or newly created
		 */
		public function acquireSound(trackConfig:TrackConfiguration, manager:SoundManager = null):SoundInstance
		{
			var sound:SoundInstance;

			++_acquiredCount;

			// Look in the pool
			var soundCount:int = _pool.length;
			for (var i:int = 0; i < soundCount; ++i)
			{
				sound = _pool[i];

				// The same type may be registered for another track, by another manager or after an unregistration
				if (sound.type == trackConfig.type && sound.track == trackConfig.track)
				{
					++_savedCount;

					_pool.removeAt(i);
					sound.isInPool = false;
					sound.setupFromPool(trackConfig, manager);
					return sound;
				}
			}

			// Create new one
			sound = new SoundInstance(trackConfig, manager);
			sound.fromPool = true; // Mark as coming from the pool to restore it later on
			return sound;
		}

		/**
		 * Releases a Sound Instance.
		 *
		 * @param sound The sound instance to release
		 * @return Whether the sound instance has been released: releasing a sound instance which is already in the pool is ignored
		 */
		public function releaseSound(sound:SoundInstance):Boolean
		{
			// Check for `null` sound instance
			if (!sound)
				throw ArgumentError("A `null` sound instance cannot be released");

			// Check for invalid sound instance
			if (sound.isDestroyed)
				throw ArgumentError("A destroyed sound instance cannot be released.");

			// Pooled twice, the sound instance would be acquired twice
			if (sound.isInPool)
			{
				trace(LOG_PREFIX + " Sound Instance '" + sound.type + "#" + sound.id + "' is already in the pool. Release ignored.");
				return false;
			}

			++_releaseCount;

			// Stop the sound
			sound.stop();

			// Reset & add back to the pool
			sound.resetAfterRelease();
			sound.isInPool = true;
			_pool.push(sound);

			return true;
		}

		/**
		 * Removes a Sound Instance from the pool, without acquiring it.
		 */
		internal function removeSound(sound:SoundInstance):void
		{
			var index:int = _pool.indexOf(sound);
			if (index != -1)
				_pool.removeAt(index);

			sound.isInPool = false;
		}

		/**
		 * Destroys the Sound Instances of the pool reading a given track, so that the track can be freed.
		 */
		internal function destroySoundsOfTrack(track:Track):void
		{
			for (var i:int = _pool.length - 1; i >= 0; --i)
			{
				var sound:SoundInstance = _pool[i];
				if (sound.track != track)
					continue;

				_pool.removeAt(i);
				sound.isInPool = false;
				sound.destroy();
			}
		}

		public function get capacity():uint
		{
			return _pool.length;
		}

		public function get acquiredCount():uint
		{
			return _acquiredCount;
		}

		public function get savedCount():uint
		{
			return _savedCount;
		}

		public function get releaseCount():uint
		{
			return _releaseCount;
		}
	}
}