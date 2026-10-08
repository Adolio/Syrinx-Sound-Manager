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
	import ch.adolio.test.Assert;
	import ch.adolio.test.ITest;

	/**
	 * Sounds which cannot get a sound channel because the max channel capacity of their manager is reached: a sound
	 * with a finite number of loops is skipped, while an infinitely looping sound is put on hold until resumed.
	 *
	 * Managers have a capacity of one channel, taken by a first sound, & a master volume of 0. Tracks last 1000 ms.
	 */
	public class ChannelCapacityTest implements ITest
	{
		private static const EPSILON:Number = 0.000001;

		private static var _typeCount:int = 0;

		public function execute():void
		{
			testFiniteSoundsSkipped();
			testSkippedSoundKeptAlive();
			testSkippedSoundReleasedToPool();
			testInfiniteLoopHeld();
			testHeldLoopResumed();
			testResumedFiniteSoundSkipped();
		}

		private function testFiniteSoundsSkipped():void
		{
			var manager:SoundManager = createFullManager();

			for each (var loops:int in [0, 2])
			{
				var completedCount:int = 0;
				var si:SoundInstance = new SoundInstance(manager.findRegisteredTrack("tone"), manager);
				si.completed.add(function(instance:SoundInstance):void { completedCount++; });
				si.play(1, 0, loops);
				Assert.equalsInt(completedCount, 1, "Completed when skipped. Loops: " + loops);
				Assert.isTrue(si.isDestroyed, "Destroyed when skipped. Loops: " + loops);
			}

			// Sounds played without keeping their instance must not pile up
			for (var i:int = 0; i < 10; ++i)
				manager.play("tone");

			Assert.equalsInt(manager.getSoundInstancesCount(), 1, "Only the playing sound kept by the manager");
			Assert.equalsInt(manager.getPlayingSoundInstancesCount(), 1, "First sound still playing");

			manager.destroyAllSoundInstances();
		}

		private function testSkippedSoundKeptAlive():void
		{
			var manager:SoundManager = createFullManager();
			var si:SoundInstance = new SoundInstance(manager.findRegisteredTrack("tone"), manager);
			si.freeWhenCompleted = false;
			si.play();
			Assert.isFalse(si.isDestroyed, "Kept alive when skipped");
			Assert.isFalse(si.isPlaying, "Not playing when skipped");
			Assert.isFalse(si.isPaused, "Not paused when skipped");
			Assert.isNull(si.manager, "Removed from the manager when skipped");

			si.destroy();
			manager.destroyAllSoundInstances();
		}

		private function testSkippedSoundReleasedToPool():void
		{
			var pool:SoundInstancesPool = SoundInstancesPool.instance;
			var manager:SoundManager = new SoundManager();
			manager.volume = 0;
			manager.maxChannelCapacity = 1;
			manager.isPoolingEnabled = true;
			var type:String = "capacity-test-" + (_typeCount++);
			manager.registerTrack(type, ProbeTrack.tone(1000));
			manager.play(type, 1, 0, -1);

			var capacity:uint = pool.capacity;
			var si:SoundInstance = manager.play(type);
			Assert.isFalse(si.isDestroyed, "Pooled instance not destroyed when skipped");
			Assert.equalsInt(pool.capacity, capacity + 1, "Skipped instance released to the pool");
			Assert.equalsInt(manager.getSoundInstancesCount(), 1, "Only the playing sound kept by the manager");

			manager.releaseAllSoundInstancesToPool();
		}

		private function testInfiniteLoopHeld():void
		{
			var manager:SoundManager = createFullManager();
			var completedCount:int = 0;
			var si:SoundInstance = new SoundInstance(manager.findRegisteredTrack("tone"), manager);
			si.completed.add(function(instance:SoundInstance):void { completedCount++; });

			si.play(1, 2300, -1);
			Assert.equalsInt(completedCount, 0, "Not completed when held");
			Assert.isFalse(si.isDestroyed, "Not destroyed when held");
			Assert.isFalse(si.isPlaying, "Not playing when held");
			Assert.isTrue(si.isPaused, "Paused when held");
			Assert.equalsNumber(si.position, 2300, EPSILON, "Start position kept when held");
			Assert.equalsInt(si.currentLoop, 2, "Current loop kept when held");
			Assert.equalsInt(manager.getSoundInstancesCount(), 2, "Held sound kept by the manager");

			manager.destroyAllSoundInstances();
		}

		private function testHeldLoopResumed():void
		{
			var manager:SoundManager = createFullManager();
			var first:SoundInstance = manager.getSoundInstances()[0];
			var resumedCount:int = 0;
			var si:SoundInstance = manager.play("tone", 1, 300, -1);
			si.resumed.add(function(instance:SoundInstance):void { resumedCount++; });

			// No channel available yet
			si.resume();
			Assert.equalsInt(resumedCount, 0, "No resumed signal while no channel is available");
			Assert.isTrue(si.isPaused, "Still paused while no channel is available");
			Assert.equalsNumber(si.position, 300, EPSILON, "Position kept while no channel is available");

			// Channel freed by the first sound
			first.stop();
			si.resume();
			Assert.equalsInt(resumedCount, 1, "Resumed signal once a channel is available");
			Assert.isTrue(si.isPlaying, "Playing once a channel is available");
			Assert.isFalse(si.isPaused, "Not paused once a channel is available");

			manager.destroyAllSoundInstances();
		}

		private function testResumedFiniteSoundSkipped():void
		{
			var manager:SoundManager = new SoundManager();
			manager.volume = 0;
			manager.registerTrack("tone", ProbeTrack.tone(1000));

			// The channel of the paused sound gets taken by another one
			var si:SoundInstance = manager.play("tone");
			si.pause();
			manager.play("tone", 1, 0, -1);
			manager.maxChannelCapacity = 1;

			var resumedCount:int = 0;
			si.resumed.add(function(instance:SoundInstance):void { resumedCount++; });
			si.resume();
			Assert.equalsInt(resumedCount, 0, "No resumed signal when skipped");
			Assert.isTrue(si.isDestroyed, "Destroyed when skipped on resume");
			Assert.equalsInt(manager.getSoundInstancesCount(), 1, "Only the playing sound kept by the manager");

			manager.destroyAllSoundInstances();
		}

		/**
		 * Creates a manager whose single channel is taken by an infinitely looping sound.
		 */
		private function createFullManager():SoundManager
		{
			var manager:SoundManager = new SoundManager();
			manager.volume = 0;
			manager.maxChannelCapacity = 1;
			manager.registerTrack("tone", ProbeTrack.tone(1000));

			var first:SoundInstance = manager.play("tone", 1, 0, -1);
			Assert.isTrue(first.isPlaying, "Not playing, a sound output device is required.");

			return manager;
		}
	}
}
