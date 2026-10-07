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
	import ch.adolio.sound.SoundManager;
	import ch.adolio.sound.TrackConfiguration;
	import ch.adolio.test.Assert;
	import ch.adolio.test.ITest;
	import flash.errors.IllegalOperationError;

	/**
	 * Track registration & unregistration through the Sound Manager, with their signals, lookups & max channel capacity.
	 */
	public class TrackRegistrationTest implements ITest
	{
		private static const EPSILON:Number = 0.000001;

		public function execute():void
		{
			testRegistration();
			testDuplicateRegistrationRejected();
			testAutomaticStartTrimAtRegistration();
			testUnregistration();
			testUnregisteredTypeCannotBePlayed();
			testMaxChannelCapacity();
		}

		private function testRegistration():void
		{
			var manager:SoundManager = new SoundManager();
			var registered:Vector.<TrackConfiguration> = new Vector.<TrackConfiguration>();
			manager.trackRegistered.add(function(config:TrackConfiguration):void { registered.push(config); });

			var track:ProbeTrack = ProbeTrack.tone(1000);
			var config:TrackConfiguration = manager.registerTrack("tone", track, 100, 200, 4096);
			Assert.isTrue(config.track == track, "Registered track");
			Assert.isTrue(config.type == "tone", "Registered type");
			Assert.equalsNumber(config.trimStartDuration, 100, EPSILON, "Registered start trim");
			Assert.equalsNumber(config.trimEndDuration, 200, EPSILON, "Registered end trim");
			Assert.equalsInt(config.sampling, 4096, "Registered sampling");

			Assert.equalsInt(registered.length, 1, "Track registered signal");
			Assert.isTrue(registered[0] == config, "Track registered signal value");

			Assert.isTrue(manager.hasTrackRegistered("tone"), "Has registered track");
			Assert.isFalse(manager.hasTrackRegistered("other"), "Has unknown track");
			Assert.isTrue(manager.findRegisteredTrack("tone") == config, "Find registered track");
			Assert.isNull(manager.findRegisteredTrack("other"), "Find unknown track");

			manager.registerTrack("other", ProbeTrack.tone(500));
			Assert.equalsInt(manager.getRegisteredTracks().length, 2, "Registered tracks count");
		}

		private function testDuplicateRegistrationRejected():void
		{
			var manager:SoundManager = new SoundManager();
			var config:TrackConfiguration = manager.registerTrack("tone", ProbeTrack.tone(1000));
			Assert.throws(ArgumentError, function():void
			{
				manager.registerTrack("tone", ProbeTrack.tone(500));
			}, "Type registered twice");
			Assert.isTrue(manager.findRegisteredTrack("tone") == config, "First registration kept");
		}

		private function testAutomaticStartTrimAtRegistration():void
		{
			var manager:SoundManager = new SoundManager();
			var config:TrackConfiguration = manager.registerTrack("tone", ProbeTrack.toneWithSilences(4410, 4410, 4410), -1);
			Assert.equalsNumber(config.trimStartDuration, 100, EPSILON, "Negative start trim detected automatically");
		}

		private function testUnregistration():void
		{
			var manager:SoundManager = new SoundManager();
			var unregistered:Vector.<TrackConfiguration> = new Vector.<TrackConfiguration>();
			manager.trackUnregistered.add(function(config:TrackConfiguration):void { unregistered.push(config); });

			var track:ProbeTrack = ProbeTrack.tone(1000);
			var config:TrackConfiguration = manager.registerTrack("tone", track);
			manager.unregisterTrack("tone");

			Assert.equalsInt(unregistered.length, 1, "Track unregistered signal");
			Assert.isTrue(unregistered[0] == config, "Track unregistered signal value");
			Assert.isFalse(manager.hasTrackRegistered("tone"), "Track no longer registered");
			Assert.equalsInt(manager.getRegisteredTracks().length, 0, "No registered tracks");
			Assert.isNull(config.track, "Configuration destroyed");
			Assert.isFalse(track.isDestroyed, "Track not destroyed");

			manager.unregisterTrack("tone");
			manager.unregisterTrack("unknown");
			Assert.equalsInt(unregistered.length, 1, "Unknown types ignored");

			manager.registerTrack("tone", ProbeTrack.tone(500));
			Assert.isTrue(manager.hasTrackRegistered("tone"), "Type registered again");
		}

		private function testUnregisteredTypeCannotBePlayed():void
		{
			var manager:SoundManager = new SoundManager();
			Assert.throws(IllegalOperationError, function():void
			{
				manager.play("unknown");
			}, "Unregistered type played");
			Assert.equalsInt(manager.getSoundInstancesCount(), 0, "No instance created");
		}

		private function testMaxChannelCapacity():void
		{
			var manager:SoundManager = new SoundManager();
			Assert.equalsInt(manager.maxChannelCapacity, SoundManager.MAX_CHANNELS, "Default capacity");

			manager.maxChannelCapacity = 8;
			Assert.equalsInt(manager.maxChannelCapacity, 8, "Capacity updated");

			Assert.throws(ArgumentError, function():void
			{
				manager.maxChannelCapacity = SoundManager.MAX_CHANNELS + 1;
			}, "Capacity above the AIR limit");
			Assert.equalsInt(manager.maxChannelCapacity, 8, "Rejected capacity not applied");
		}
	}
}
