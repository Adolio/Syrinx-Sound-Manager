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
		private var _verbose:Boolean = false;

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
				if (sound.type == trackConfig.type)
				{
					++_savedCount;

					if (_verbose)
						trace(LOG_PREFIX + " Sound Instance acquired from pool. Saved instantiations: " + _savedCount);

					sound.manager = manager;
					sound.fromPool = true; // Mark as coming from the pool to restore it later on
					return _pool.removeAt(i);
				}
			}

			// Create new one
			if (_verbose)
				trace(LOG_PREFIX + " Sound Instance created from pool.");

			sound = new SoundInstance(trackConfig, manager);
			sound.fromPool = true; // Mark as coming from the pool to restore it later on
			return sound;
		}

		/**
		 * Releases a Sound Instance.
		 *
		 * @param sound The sound instance to release
		 */
		public function releaseSound(sound:SoundInstance):void
		{
			// Check for `null` sound instance
			if (!sound)
				throw ArgumentError("A `null` sound instance cannot be released");

			// Check for invalid sound instance
			if (sound.isDestroyed)
				throw ArgumentError("A destroyed sound instance cannot be released.");

			++_releaseCount;

			// Stop the sound
			sound.stop();

			// Reset & add back to the pool
			sound.resetAfterRelease();
			_pool.push(sound);

			// Debug
			if (_verbose)
				trace(LOG_PREFIX + " Sound Instance released to pool.");
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