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

	/**
	 * Destruction of a Sound Manager: its sound instances are freed, its tracks unregistered, its signals cleared & its
	 * max channel capacity no longer counted.
	 *
	 * Managers have a master volume of 0. Track types are unique to each scenario: the pool is shared by all the tests.
	 */
	public class SoundManagerDestructionTest implements ITest
	{
		private static var _typeCount:int = 0;

		public function execute():void
		{
			testSoundInstancesDestroyed();
			testPooledSoundInstancesFreed();
			testTracksUnregistered();
			testSignalsCleared();
			testMaxChannelCapacityNoLongerCounted();
			testSecondDestructionIgnored();
		}

		private function testSoundInstancesDestroyed():void
		{
			var manager:SoundManager = createManager(false);
			var config:TrackConfiguration = registerTone(manager);
			var played:SoundInstance = manager.play(config.type, 1, 0, -1);
			var idle:SoundInstance = new SoundInstance(config, manager);
			Assert.isTrue(played.isPlaying, "Not playing, a sound output device is required.");

			var removedCount:int = 0;
			manager.soundInstanceRemoved.add(function(si:SoundInstance):void { removedCount++; });

			Assert.isFalse(manager.isDestroyed, "Not destroyed yet");
			manager.destroy();
			Assert.isTrue(manager.isDestroyed, "Destroyed");
			Assert.isTrue(played.isDestroyed, "Played instance destroyed");
			Assert.isTrue(idle.isDestroyed, "Idle instance destroyed");
			Assert.equalsInt(removedCount, 2, "Sound instance removed signals");
			Assert.equalsInt(manager.getSoundInstancesCount(), 0, "No instance left");
		}

		private function testPooledSoundInstancesFreed():void
		{
			var pool:SoundInstancesPool = SoundInstancesPool.instance;
			var manager:SoundManager = createManager(true);
			var config:TrackConfiguration = registerTone(manager);
			var availableCount:uint = pool.availableCount;
			var si1:SoundInstance = manager.play(config.type, 1, 0, -1);
			var si2:SoundInstance = manager.play(config.type, 1, 0, -1);

			var releasedCount:int = 0;
			manager.soundInstanceReleasedToPool.add(function(si:SoundInstance, releasePool:SoundInstancesPool):void { releasedCount++; });

			// Released to the pool, then dropped from it as their track gets unregistered
			manager.destroy();
			Assert.equalsInt(releasedCount, 2, "Sound instance released to pool signals");
			Assert.isFalse(si1.isPlaying, "First pooled instance stopped");
			Assert.isTrue(si1.isDestroyed, "First pooled instance destroyed");
			Assert.isTrue(si2.isDestroyed, "Second pooled instance destroyed");
			Assert.equalsInt(pool.availableCount, availableCount, "No instance of the destroyed manager left in the pool");
			Assert.equalsInt(manager.getSoundInstancesCount(), 0, "No instance left");
		}

		private function testTracksUnregistered():void
		{
			var manager:SoundManager = createManager(false);
			var track:ProbeTrack = ProbeTrack.tone(1000);
			var config1:TrackConfiguration = manager.registerTrack("destruction-test-" + (_typeCount++), track);
			var config2:TrackConfiguration = registerTone(manager);
			var type1:String = config1.type;

			var unregisteredCount:int = 0;
			manager.trackUnregistered.add(function(config:TrackConfiguration):void { unregisteredCount++; });

			manager.destroy();
			Assert.equalsInt(unregisteredCount, 2, "Track unregistered signals");
			Assert.equalsInt(manager.getRegisteredTracks().length, 0, "No track left");
			Assert.isFalse(manager.hasTrackRegistered(type1), "Track no longer registered");
			Assert.isNull(config1.track, "First configuration destroyed");
			Assert.isNull(config2.track, "Second configuration destroyed");
			Assert.isFalse(track.isDestroyed, "Track not destroyed");
		}

		private function testSignalsCleared():void
		{
			var manager:SoundManager = createManager(true);
			var listener:Function = function(value:Object):void {};
			manager.trackRegistered.add(listener);
			manager.trackUnregistered.add(listener);
			manager.soundInstanceAdded.add(listener);
			manager.soundInstanceRemoved.add(listener);
			manager.soundInstanceReleasedToPool.add(function(si:SoundInstance, releasePool:SoundInstancesPool):void {});

			manager.destroy();
			Assert.equalsInt(manager.trackRegistered.numListeners, 0, "Track registered listeners");
			Assert.equalsInt(manager.trackUnregistered.numListeners, 0, "Track unregistered listeners");
			Assert.equalsInt(manager.soundInstanceAdded.numListeners, 0, "Sound instance added listeners");
			Assert.equalsInt(manager.soundInstanceRemoved.numListeners, 0, "Sound instance removed listeners");
			Assert.equalsInt(manager.soundInstanceReleasedToPool.numListeners, 0, "Sound instance released to pool listeners");
		}

		private function testMaxChannelCapacityNoLongerCounted():void
		{
			// Managers of other tests may be collected at any time, which can only lower the total further
			var manager:SoundManager = createManager(false);
			manager.maxChannelCapacity = 7;
			var total:uint = SoundManager.totalMaxChannelCapacity;

			manager.destroy();
			Assert.isTrue(SoundManager.totalMaxChannelCapacity <= total - 7, "Capacity of the destroyed manager no longer counted. Total: " + SoundManager.totalMaxChannelCapacity + ", before: " + total);
		}

		private function testSecondDestructionIgnored():void
		{
			var manager:SoundManager = createManager(false);
			registerTone(manager);
			manager.destroy();

			var unregisteredCount:int = 0;
			manager.trackUnregistered.add(function(config:TrackConfiguration):void { unregisteredCount++; });
			manager.destroy();
			Assert.equalsInt(unregisteredCount, 0, "Nothing done by a second destruction");
			Assert.isTrue(manager.isDestroyed, "Still destroyed");
		}

		private function createManager(isPoolingEnabled:Boolean):SoundManager
		{
			var manager:SoundManager = new SoundManager();
			manager.volume = 0;
			manager.isPoolingEnabled = isPoolingEnabled;
			return manager;
		}

		private function registerTone(manager:SoundManager):TrackConfiguration
		{
			return manager.registerTrack("destruction-test-" + (_typeCount++), ProbeTrack.tone(1000));
		}
	}
}
