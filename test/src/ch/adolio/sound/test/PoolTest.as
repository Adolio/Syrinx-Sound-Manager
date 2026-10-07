// =================================================================================================
//
//	Syrinx - Sound Manager
//	Copyright (c) 2019-2026 Aurelien Da Campo (Adolio), All Rights Reserved.
//
//	This program is free software. You can redistribute and/or modify it
//	in accordance with the terms of the accompanying license agreement.
//
// =================================================================================================

package ch.adolio.sound.test
{
	import ch.adolio.sound.SoundInstance;
	import ch.adolio.sound.SoundInstancesPool;
	import ch.adolio.sound.SoundManager;
	import ch.adolio.sound.TrackConfiguration;
	import ch.adolio.test.Assert;
	import ch.adolio.test.ITest;
	import flash.errors.IllegalOperationError;

	/**
	 * Sound instances pooling without playback: acquisition, release, recycling & statistics.
	 *
	 * The pool is a singleton shared by all the tests: each scenario uses its own track types & checks the statistics
	 * relatively to their values at its start.
	 */
	public class PoolTest implements ITest
	{
		private static var _typeCount:int = 0;

		public function execute():void
		{
			testAcquisition();
			testRelease();
			testRecycling();
			testReleaseAll();
			testInvalidReleasesRejected();
			testPoolingDisabled();
		}

		private function testAcquisition():void
		{
			var pool:SoundInstancesPool = SoundInstancesPool.instance;
			var manager:SoundManager = createManager();
			var config:TrackConfiguration = registerTone(manager);
			var acquiredCount:uint = pool.acquiredCount;

			var si:SoundInstance = pool.acquireSound(config, manager);
			Assert.isTrue(si.isFromPool, "Instance from pool");
			Assert.isTrue(si.type == config.type, "Type");
			Assert.isTrue(si.manager == manager, "Manager");
			Assert.equalsInt(manager.getSoundInstancesCount(), 1, "Instance added to the manager");
			Assert.equalsInt(pool.acquiredCount, acquiredCount + 1, "Acquired count");
		}

		private function testRelease():void
		{
			var pool:SoundInstancesPool = SoundInstancesPool.instance;
			var manager:SoundManager = createManager();
			var si:SoundInstance = pool.acquireSound(registerTone(manager), manager);
			var capacity:uint = pool.capacity;
			var releaseCount:uint = pool.releaseCount;

			var releasedToPool:int = 0;
			var removed:int = 0;
			var stopped:int = 0;
			manager.soundInstanceReleasedToPool.add(function(instance:SoundInstance, releasePool:SoundInstancesPool):void
			{
				Assert.isTrue(instance == si, "Released instance");
				Assert.isTrue(releasePool == pool, "Release pool");
				releasedToPool++;
			});
			manager.soundInstanceRemoved.add(function(instance:SoundInstance):void { removed++; });
			si.stopped.add(function(instance:SoundInstance):void { stopped++; });

			manager.releaseSoundInstanceToPool(si);
			Assert.equalsInt(releasedToPool, 1, "Sound instance released to pool signal");
			Assert.equalsInt(removed, 1, "Sound instance removed signal");
			Assert.equalsInt(stopped, 1, "Stopped on release");
			Assert.equalsInt(manager.getSoundInstancesCount(), 0, "Removed from the manager");
			Assert.isNull(si.manager, "Manager released");
			Assert.isFalse(si.isDestroyed, "Not destroyed");
			Assert.equalsInt(pool.capacity, capacity + 1, "Pool capacity");
			Assert.equalsInt(pool.releaseCount, releaseCount + 1, "Release count");

			// Signals are cleared on release
			si.stop();
			Assert.equalsInt(stopped, 1, "Listeners cleared on release");
		}

		private function testRecycling():void
		{
			var pool:SoundInstancesPool = SoundInstancesPool.instance;
			var manager1:SoundManager = createManager();
			var config:TrackConfiguration = registerTone(manager1);
			var si:SoundInstance = pool.acquireSound(config, manager1);
			si.pan = 0.5;
			si.isMuted = true;
			si.pitch = 1.5;
			manager1.releaseSoundInstanceToPool(si);

			var manager2:SoundManager = createManager();
			var savedCount:uint = pool.savedCount;
			var capacity:uint = pool.capacity;
			var recycled:SoundInstance = pool.acquireSound(config, manager2);
			Assert.isTrue(recycled == si, "Instance recycled");
			Assert.equalsInt(pool.savedCount, savedCount + 1, "Saved count");
			Assert.equalsInt(pool.capacity, capacity - 1, "Pool capacity");
			Assert.isTrue(recycled.manager == manager2, "Added to the new manager");
			Assert.equalsInt(manager2.getSoundInstancesCount(), 1, "New manager holds the instance");
			Assert.isTrue(recycled.isFromPool, "Still from pool");
			Assert.equalsNumber(recycled.pan, 0, 0.000001, "Pan reset");
			Assert.isFalse(recycled.isMuted, "Mute reset");
			Assert.equalsNumber(recycled.pitch, SoundInstance.PITCH_DEFAULT, 0.000001, "Pitch reset");
			Assert.isFalse(recycled.isStarted, "Not started");

			// Another type is not recycled from this instance
			var other:SoundInstance = pool.acquireSound(registerTone(manager2), manager2);
			Assert.isFalse(other == si, "Other type gets another instance");
			Assert.isTrue(other.isFromPool, "Other instance from pool");
		}

		private function testReleaseAll():void
		{
			var pool:SoundInstancesPool = SoundInstancesPool.instance;
			var manager:SoundManager = createManager();
			var config:TrackConfiguration = registerTone(manager);
			for (var i:int = 0; i < 3; ++i)
				pool.acquireSound(config, manager);

			var capacity:uint = pool.capacity;
			manager.releaseAllSoundInstancesToPool();
			Assert.equalsInt(manager.getSoundInstancesCount(), 0, "All instances removed from the manager");
			Assert.equalsInt(pool.capacity, capacity + 3, "All instances released to the pool");
		}

		private function testInvalidReleasesRejected():void
		{
			var pool:SoundInstancesPool = SoundInstancesPool.instance;
			var manager:SoundManager = createManager();
			var si:SoundInstance = pool.acquireSound(registerTone(manager), manager);
			si.destroy();

			var capacity:uint = pool.capacity;
			Assert.throws(ArgumentError, function():void { pool.releaseSound(null); }, "Null instance released");
			Assert.throws(ArgumentError, function():void { pool.releaseSound(si); }, "Destroyed instance released");
			Assert.equalsInt(pool.capacity, capacity, "Rejected instances not pooled");
		}

		private function testPoolingDisabled():void
		{
			var manager:SoundManager = new SoundManager();
			Assert.isFalse(manager.isPoolingEnabled, "Pooling disabled by default");

			var si:SoundInstance = new SoundInstance(registerTone(manager), manager);
			Assert.throws(IllegalOperationError, function():void { manager.releaseSoundInstanceToPool(si); }, "Release while pooling disabled");
			Assert.throws(IllegalOperationError, function():void { manager.releaseAllSoundInstancesToPool(); }, "Release all while pooling disabled");
			Assert.equalsInt(manager.getSoundInstancesCount(), 1, "Instance kept by the manager");
		}

		private function createManager():SoundManager
		{
			var manager:SoundManager = new SoundManager();
			manager.isPoolingEnabled = true;
			return manager;
		}

		private function registerTone(manager:SoundManager):TrackConfiguration
		{
			return manager.registerTrack("pool-test-" + (_typeCount++), ProbeTrack.tone(1000));
		}
	}
}
