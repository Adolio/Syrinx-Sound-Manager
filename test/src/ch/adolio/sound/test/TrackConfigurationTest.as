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
	import ch.adolio.sound.TrackConfiguration;
	import ch.adolio.test.Assert;
	import ch.adolio.test.ITest;

	/**
	 * Defaults, sampling & trimming validation, start trim detection, cloning & time conversions of track configurations.
	 */
	public class TrackConfigurationTest implements ITest
	{
		private static const EPSILON:Number = 0.000001;
		private static const TRIM_EPSILON:Number = 0.05; // Trim detection works in samples (1 / 44.1 ms)

		public function execute():void
		{
			testDefaults();
			testSamplingBounds();
			testTrimValidation();
			testStartTrimDetection();
			testAutomaticStartTrim();
			testClone();
			testTimeConversions();
			testDestroy();
		}

		private function testDefaults():void
		{
			var track:ProbeTrack = ProbeTrack.tone(1000);
			var config:TrackConfiguration = new TrackConfiguration(track, "type");
			Assert.isTrue(config.track == track, "Track");
			Assert.isTrue(config.type == "type", "Type");
			Assert.equalsInt(config.sampling, TrackConfiguration.SAMPLING_MIN_VALUE, "Default sampling");
			Assert.equalsNumber(config.baseVolume, 1, EPSILON, "Default base volume");
			Assert.equalsNumber(config.trimStartDuration, 0, EPSILON, "Default start trim");
			Assert.equalsNumber(config.trimEndDuration, 0, EPSILON, "Default end trim");
		}

		private function testSamplingBounds():void
		{
			var config:TrackConfiguration = new TrackConfiguration(ProbeTrack.tone(1000), "type");

			config.sampling = TrackConfiguration.SAMPLING_MAX_VALUE;
			Assert.equalsInt(config.sampling, TrackConfiguration.SAMPLING_MAX_VALUE, "Max sampling accepted");
			config.sampling = TrackConfiguration.SAMPLING_MIN_VALUE;
			Assert.equalsInt(config.sampling, TrackConfiguration.SAMPLING_MIN_VALUE, "Min sampling accepted");

			Assert.throws(ArgumentError, function():void { config.sampling = TrackConfiguration.SAMPLING_MIN_VALUE - 1; }, "Sampling below min");
			Assert.throws(ArgumentError, function():void { config.sampling = TrackConfiguration.SAMPLING_MAX_VALUE + 1; }, "Sampling above max");
			Assert.equalsInt(config.sampling, TrackConfiguration.SAMPLING_MIN_VALUE, "Rejected sampling not applied");

			Assert.throws(ArgumentError, function():void
			{
				new TrackConfiguration(ProbeTrack.tone(1000), "type", 0, 0, TrackConfiguration.SAMPLING_MAX_VALUE + 1);
			}, "Invalid sampling in constructor");
		}

		private function testTrimValidation():void
		{
			var config:TrackConfiguration = new TrackConfiguration(ProbeTrack.tone(1000), "type", 400, 400);
			Assert.equalsNumber(config.trimStartDuration, 400, EPSILON, "Start trim");
			Assert.equalsNumber(config.trimEndDuration, 400, EPSILON, "End trim");

			Assert.throws(ArgumentError, function():void { config.trimEndDuration = 700; }, "End trim exceeding the length");
			Assert.throws(ArgumentError, function():void { config.trimStartDuration = 700; }, "Start trim exceeding the length");
			Assert.equalsNumber(config.trimStartDuration, 400, EPSILON, "Rejected start trim not applied");
			Assert.equalsNumber(config.trimEndDuration, 400, EPSILON, "Rejected end trim not applied");

			Assert.throws(ArgumentError, function():void
			{
				new TrackConfiguration(ProbeTrack.tone(1000), "type", 600, 600);
			}, "Trims exceeding the length in constructor");
		}

		private function testStartTrimDetection():void
		{
			// 100 ms of silence, 100 ms of tone, 100 ms of silence
			var config:TrackConfiguration = new TrackConfiguration(ProbeTrack.toneWithSilences(4410, 4410, 4410), "type");
			Assert.equalsNumber(config.findStartTrimDuration(0.01), 100, TRIM_EPSILON, "Leading silence of 100 ms");

			config = new TrackConfiguration(ProbeTrack.toneWithSilences(0, 4410, 4410), "type");
			Assert.equalsNumber(config.findStartTrimDuration(0.01), 0, TRIM_EPSILON, "No leading silence");

			// Samples below the threshold are silent
			var track:ProbeTrack = ProbeTrack.fromFunction(13230, function(i:int):Number
			{
				return i < 4410 ? 0.005 : 0.5;
			});
			config = new TrackConfiguration(track, "type");
			Assert.equalsNumber(config.findStartTrimDuration(0.01), 100, TRIM_EPSILON, "Leading samples below the threshold");
			Assert.equalsNumber(config.findStartTrimDuration(0.001), 0, TRIM_EPSILON, "Leading samples above a lower threshold");
		}

		private function testAutomaticStartTrim():void
		{
			var config:TrackConfiguration = new TrackConfiguration(ProbeTrack.toneWithSilences(4410, 4410, 4410), "type", -1);
			Assert.equalsNumber(config.trimStartDuration, 100, TRIM_EPSILON, "Negative start trim detected automatically");
		}

		private function testClone():void
		{
			var config:TrackConfiguration = new TrackConfiguration(ProbeTrack.tone(1000), "type", 100, 200, 4096);
			var clone:TrackConfiguration = config.clone();
			Assert.isFalse(clone == config, "Clone is a new object");
			Assert.isTrue(clone.track == config.track, "Cloned track");
			Assert.isTrue(clone.type == config.type, "Cloned type");
			Assert.equalsNumber(clone.trimStartDuration, 100, EPSILON, "Cloned start trim");
			Assert.equalsNumber(clone.trimEndDuration, 200, EPSILON, "Cloned end trim");
			Assert.equalsInt(clone.sampling, 4096, "Cloned sampling");
		}

		private function testTimeConversions():void
		{
			var config:TrackConfiguration = new TrackConfiguration(ProbeTrack.tone(1000), "type");
			Assert.equalsNumber(config.timeToSamples(1000), 44100, EPSILON, "1 second in samples");
			Assert.equalsNumber(config.samplesToTime(44100), 1000, EPSILON, "44100 samples in milliseconds");
			Assert.equalsNumber(config.timeToSamples(10.5), 463, EPSILON, "Samples rounded");
		}

		private function testDestroy():void
		{
			var track:ProbeTrack = ProbeTrack.tone(1000);
			var config:TrackConfiguration = new TrackConfiguration(track, "type");
			config.destroy();
			Assert.isNull(config.track, "Track released");
			Assert.isNull(config.type, "Type released");
			Assert.isFalse(track.isDestroyed, "Track not destroyed by the configuration");
		}
	}
}
