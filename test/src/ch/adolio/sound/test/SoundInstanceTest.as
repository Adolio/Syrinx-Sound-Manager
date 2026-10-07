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
	import ch.adolio.sound.SoundManager;
	import ch.adolio.sound.TrackConfiguration;
	import ch.adolio.test.Assert;
	import ch.adolio.test.ITest;

	/**
	 * Sound instances which are not played: registration to managers, initial status, lengths, volumes, pan, mute,
	 * position before start & destruction.
	 *
	 * The track lasts 1000 ms, trimmed by 100 ms at the start & 200 ms at the end.
	 */
	public class SoundInstanceTest implements ITest
	{
		private static const EPSILON:Number = 0.000001;

		public function execute():void
		{
			testRegistrationToManager();
			testInitialStatus();
			testVolumes();
			testPanAndMute();
			testPositionBeforeStart();
			testManagerChange();
			testDestruction();
			testDestroyAll();
			testNullConfigurationRejected();
		}

		private function testRegistrationToManager():void
		{
			var manager:SoundManager = new SoundManager();
			var config:TrackConfiguration = registerTone(manager);
			var added:Vector.<SoundInstance> = new Vector.<SoundInstance>();
			manager.soundInstanceAdded.add(function(si:SoundInstance):void { added.push(si); });

			var si:SoundInstance = new SoundInstance(config, manager);
			Assert.equalsInt(added.length, 1, "Sound instance added signal");
			Assert.isTrue(added[0] == si, "Sound instance added signal value");
			Assert.isTrue(si.manager == manager, "Manager");
			Assert.equalsInt(manager.getSoundInstancesCount(), 1, "Instances count");
			Assert.equalsInt(manager.getPlayingSoundInstancesCount(), 0, "Playing instances count");
			Assert.isTrue(manager.hasSoundInstancesOfType("tone"), "Has instances of type");
			Assert.isFalse(manager.hasSoundInstancesOfType("other"), "Has instances of unknown type");
			Assert.equalsInt(manager.getSoundInstancesByType("tone").length, 1, "Instances by type");
			Assert.equalsInt(manager.getSoundInstancesByType("other").length, 0, "Instances by unknown type");

			// The returned list is a copy
			manager.getSoundInstances().length = 0;
			Assert.equalsInt(manager.getSoundInstances().length, 1, "Instances list copied");

			var other:SoundInstance = new SoundInstance(config, manager);
			Assert.isFalse(other.id == si.id, "Unique ids");
			Assert.equalsInt(manager.getSoundInstancesCount(), 2, "Instances count after a second creation");
		}

		private function testInitialStatus():void
		{
			var manager:SoundManager = new SoundManager();
			var si:SoundInstance = new SoundInstance(registerTone(manager), manager);
			Assert.isTrue(si.type == "tone", "Type");
			Assert.equalsNumber(si.length, 700, EPSILON, "Trimmed length");
			Assert.equalsNumber(si.totalLength, 700, EPSILON, "Total length without loops");
			Assert.equalsInt(si.loops, 0, "Loops");
			Assert.equalsInt(si.currentLoop, 0, "Current loop");
			Assert.equalsInt(si.loopsRemaining, 0, "Loops remaining");
			Assert.equalsNumber(si.position, 0, EPSILON, "Position");
			Assert.equalsNumber(si.positionRatio, 0, EPSILON, "Position ratio");
			Assert.equalsNumber(si.remainingTime, 700, EPSILON, "Remaining time");
			Assert.equalsNumber(si.pitch, SoundInstance.PITCH_DEFAULT, EPSILON, "Pitch");
			Assert.isFalse(si.isStarted, "Not started");
			Assert.isFalse(si.isPlaying, "Not playing");
			Assert.isFalse(si.isPaused, "Not paused");
			Assert.isFalse(si.isMuted, "Not muted");
			Assert.isFalse(si.isFromPool, "Not from pool");
			Assert.isFalse(si.isDestroyed, "Not destroyed");
			Assert.isTrue(si.freeWhenCompleted, "Freed when completed by default");
		}

		private function testVolumes():void
		{
			var manager:SoundManager = new SoundManager();
			var config:TrackConfiguration = registerTone(manager);
			config.baseVolume = 0.5;

			var si:SoundInstance = new SoundInstance(config, manager);
			Assert.equalsNumber(si.volume, SoundInstance.VOLUME_MAX, EPSILON, "Default volume");
			Assert.equalsNumber(si.baseVolume, 0.5, EPSILON, "Base volume from configuration");

			si.volume = 0.4;
			manager.volume = 0.5;
			Assert.equalsNumber(si.mixedVolume, 0.4 * 0.5 * 0.5, EPSILON, "Mixed volume");

			si.volume = 2;
			Assert.equalsNumber(si.volume, SoundInstance.VOLUME_MAX, EPSILON, "Volume clamped to max");
			si.volume = -1;
			Assert.equalsNumber(si.volume, SoundInstance.VOLUME_MIN, EPSILON, "Volume clamped to min");

			si.baseVolume = 2;
			Assert.equalsNumber(si.baseVolume, SoundInstance.VOLUME_MAX, EPSILON, "Base volume clamped to max");
			si.baseVolume = -1;
			Assert.equalsNumber(si.baseVolume, SoundInstance.VOLUME_MIN, EPSILON, "Base volume clamped to min");
		}

		private function testPanAndMute():void
		{
			var manager:SoundManager = new SoundManager();
			var si:SoundInstance = new SoundInstance(registerTone(manager), manager);
			Assert.equalsNumber(si.pan, 0, EPSILON, "Default pan");

			si.pan = -0.5;
			Assert.equalsNumber(si.pan, -0.5, EPSILON, "Pan");
			si.pan = 2;
			Assert.equalsNumber(si.pan, 1, EPSILON, "Pan clamped to right");
			si.pan = -3;
			Assert.equalsNumber(si.pan, -1, EPSILON, "Pan clamped to left");

			si.isMuted = true;
			Assert.isTrue(si.isMuted, "Muted");
			si.isMuted = false;
			Assert.isFalse(si.isMuted, "Unmuted");
		}

		private function testPositionBeforeStart():void
		{
			var manager:SoundManager = new SoundManager();
			var si:SoundInstance = new SoundInstance(registerTone(manager), manager);

			si.position = 350;
			Assert.equalsNumber(si.position, 350, EPSILON, "Position set before start");
			Assert.equalsNumber(si.positionRatio, 0.5, EPSILON, "Position ratio from position");
			Assert.isFalse(si.isPlaying, "Still not playing");

			si.positionRatio = 0.25;
			Assert.equalsNumber(si.position, 175, EPSILON, "Position from position ratio");

			Assert.throws(ArgumentError, function():void { si.position = -1; }, "Negative position");
			Assert.throws(ArgumentError, function():void { si.position = 701; }, "Position beyond the total length");
			Assert.throws(ArgumentError, function():void { si.positionRatio = 1.5; }, "Position ratio above 1");
			Assert.throws(ArgumentError, function():void { si.positionRatio = -0.5; }, "Negative position ratio");
			Assert.equalsNumber(si.position, 175, EPSILON, "Rejected positions not applied");
		}

		private function testManagerChange():void
		{
			var manager1:SoundManager = new SoundManager();
			var manager2:SoundManager = new SoundManager();
			manager2.volume = 0.5;
			var removedFrom1:int = 0;
			var addedTo2:int = 0;
			manager1.soundInstanceRemoved.add(function(si:SoundInstance):void { removedFrom1++; });
			manager2.soundInstanceAdded.add(function(si:SoundInstance):void { addedTo2++; });

			var si:SoundInstance = new SoundInstance(registerTone(manager1), manager1);
			si.manager = manager2;
			Assert.equalsInt(removedFrom1, 1, "Removed from the first manager");
			Assert.equalsInt(addedTo2, 1, "Added to the second manager");
			Assert.equalsInt(manager1.getSoundInstancesCount(), 0, "First manager empty");
			Assert.equalsInt(manager2.getSoundInstancesCount(), 1, "Second manager holds the instance");
			Assert.equalsNumber(si.mixedVolume, 0.5, EPSILON, "Mixed with the second manager volume");

			si.manager = null;
			Assert.isNull(si.manager, "No manager");
			Assert.equalsInt(manager2.getSoundInstancesCount(), 0, "Removed from the second manager");
			Assert.equalsNumber(si.mixedVolume, 1, EPSILON, "Mixed volume without manager");
		}

		private function testDestruction():void
		{
			var manager:SoundManager = new SoundManager();
			var si:SoundInstance = new SoundInstance(registerTone(manager), manager);
			var destroyedCount:int = 0;
			var removedCount:int = 0;
			si.destroyed.add(function(instance:SoundInstance):void { destroyedCount++; });
			manager.soundInstanceRemoved.add(function(instance:SoundInstance):void { removedCount++; });

			si.destroy();
			Assert.isTrue(si.isDestroyed, "Destroyed");
			Assert.equalsInt(destroyedCount, 1, "Destroyed signal");
			Assert.equalsInt(removedCount, 1, "Sound instance removed signal");
			Assert.isNull(si.manager, "Manager released");
			Assert.equalsInt(manager.getSoundInstancesCount(), 0, "Removed from the manager");

			si.destroy();
			Assert.equalsInt(removedCount, 1, "Second destruction ignored");
		}

		private function testDestroyAll():void
		{
			var manager:SoundManager = new SoundManager();
			var config:TrackConfiguration = registerTone(manager);
			var instances:Vector.<SoundInstance> = new <SoundInstance>[
				new SoundInstance(config, manager),
				new SoundInstance(config, manager),
				new SoundInstance(config, manager)];

			manager.destroyAllSoundInstances(false);
			Assert.equalsInt(manager.getSoundInstancesCount(), 0, "All instances removed");

			for each (var si:SoundInstance in instances)
				Assert.isTrue(si.isDestroyed, "Instance #" + si.id + " destroyed");
		}

		private function testNullConfigurationRejected():void
		{
			Assert.throws(ArgumentError, function():void
			{
				new SoundInstance(null);
			}, "Null track configuration");
		}

		private function registerTone(manager:SoundManager):TrackConfiguration
		{
			return manager.registerTrack("tone", ProbeTrack.tone(1000), 100, 200);
		}
	}
}
