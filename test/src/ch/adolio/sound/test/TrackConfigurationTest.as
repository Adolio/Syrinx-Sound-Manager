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
	 * Defaults, sampling & trimming validation, trims detection, cloning & time conversions of track configurations.
	 *
	 * Trims detection is expected to be exact to the sample: 4410 samples last 100 ms.
	 */
	public class TrackConfigurationTest implements ITest
	{
		private static const EPSILON:Number = 0.000001;

		public function execute():void
		{
			testDefaults();
			testSamplingBounds();
			testTrimValidation();
			testTrimErrorsReportTotalTrimming();
			testStartTrimDetection();
			testEndTrimDetection();
			testAutomaticTrims();
			testFindTrim();
			testSilentTracks();
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

		private function testTrimErrorsReportTotalTrimming():void
		{
			// The rejected value added to the other trim: 800 + 400, then 300 + 800
			var config:TrackConfiguration = new TrackConfiguration(ProbeTrack.tone(1000), "type", 300, 400);
			assertTrimErrorReports(function():void { config.trimStartDuration = 800; }, 1200, "Start trim");
			assertTrimErrorReports(function():void { config.trimEndDuration = 800; }, 1100, "End trim");
		}

		private function assertTrimErrorReports(block:Function, trimmingLength:Number, context:String):void
		{
			var message:String = "";
			try
			{
				block();
			}
			catch (error:ArgumentError)
			{
				message = error.message;
			}

			Assert.isTrue(message.indexOf("Trimming length: " + trimmingLength) != -1, context + " error reporting a trimming of " + trimmingLength + ". Message: " + message);
		}

		private function testStartTrimDetection():void
		{
			// 100 ms of silence, 100 ms of tone, 100 ms of silence
			var config:TrackConfiguration = new TrackConfiguration(ProbeTrack.toneWithSilences(4410, 4410, 4410), "type");
			Assert.equalsNumber(config.findStartTrimDuration(0.01), 100, EPSILON, "Leading silence of 100 ms");
			Assert.equalsNumber(config.findStartTrimDuration(0.01, 50), 100, EPSILON, "Leading silence scanned from 50 ms");

			config.sampling = TrackConfiguration.SAMPLING_MAX_VALUE;
			Assert.equalsNumber(config.findStartTrimDuration(0.01), 100, EPSILON, "Leading silence with the max sampling");

			config = new TrackConfiguration(ProbeTrack.toneWithSilences(0, 4410, 4410), "type");
			Assert.equalsNumber(config.findStartTrimDuration(0.01), 0, EPSILON, "No leading silence");

			config = new TrackConfiguration(ProbeTrack.toneWithSilences(3000, 4410, 0), "type");
			Assert.equalsNumber(config.findStartTrimDuration(0.01), 3000 / ProbeTrack.SAMPLE_RATE_MS, EPSILON, "Leading silence not aligned on the sampling");

			// Samples below the threshold are silent
			var track:ProbeTrack = ProbeTrack.fromFunction(13230, function(i:int):Number
			{
				return i < 4410 ? 0.005 : 0.5;
			});
			config = new TrackConfiguration(track, "type");
			Assert.equalsNumber(config.findStartTrimDuration(0.01), 100, EPSILON, "Leading samples below the threshold");
			Assert.equalsNumber(config.findStartTrimDuration(0.001), 0, EPSILON, "Leading samples above a lower threshold");
		}

		private function testEndTrimDetection():void
		{
			// 100 ms of silence, 100 ms of tone, 100 ms of silence
			var track:ProbeTrack = ProbeTrack.toneWithSilences(4410, 4410, 4410);
			var config:TrackConfiguration = new TrackConfiguration(track, "type");
			Assert.equalsNumber(config.findEndTrimDuration(0.01, track.length), 100, EPSILON, "Trailing silence of 100 ms");

			config.sampling = TrackConfiguration.SAMPLING_MAX_VALUE;
			Assert.equalsNumber(config.findEndTrimDuration(0.01, track.length), 100, EPSILON, "Trailing silence with the max sampling");

			track = ProbeTrack.toneWithSilences(4410, 4410, 0);
			config = new TrackConfiguration(track, "type");
			Assert.equalsNumber(config.findEndTrimDuration(0.01, track.length), 0, EPSILON, "No trailing silence");

			track = ProbeTrack.toneWithSilences(0, 4410, 100);
			config = new TrackConfiguration(track, "type");
			Assert.equalsNumber(config.findEndTrimDuration(0.01, track.length), 100 / ProbeTrack.SAMPLE_RATE_MS, EPSILON, "Trailing silence shorter than the sampling");

			track = ProbeTrack.toneWithSilences(0, 4410, 3000);
			config = new TrackConfiguration(track, "type");
			Assert.equalsNumber(config.findEndTrimDuration(0.01, track.length), 3000 / ProbeTrack.SAMPLE_RATE_MS, EPSILON, "Trailing silence not aligned on the sampling");

			// A single sample after a silence must be kept
			track = ProbeTrack.fromFunction(8820, function(i:int):Number
			{
				return i < 4410 || i == 8000 ? 0.5 : 0;
			});
			config = new TrackConfiguration(track, "type");
			Assert.equalsNumber(config.findEndTrimDuration(0.01, track.length), 819 / ProbeTrack.SAMPLE_RATE_MS, EPSILON, "Isolated sample after a silence");

			// Samples below the threshold are silent
			track = ProbeTrack.fromFunction(13230, function(i:int):Number
			{
				return i < 8820 ? 0.5 : 0.005;
			});
			config = new TrackConfiguration(track, "type");
			Assert.equalsNumber(config.findEndTrimDuration(0.01, track.length), 100, EPSILON, "Trailing samples below the threshold");
			Assert.equalsNumber(config.findEndTrimDuration(0.001, track.length), 0, EPSILON, "Trailing samples above a lower threshold");
		}

		private function testAutomaticTrims():void
		{
			var config:TrackConfiguration = new TrackConfiguration(ProbeTrack.toneWithSilences(4410, 4410, 4410), "type", -1, -1);
			Assert.equalsNumber(config.trimStartDuration, 100, EPSILON, "Negative start trim detected automatically");
			Assert.equalsNumber(config.trimEndDuration, 100, EPSILON, "Negative end trim detected automatically");
		}

		private function testFindTrim():void
		{
			var config:TrackConfiguration = new TrackConfiguration(ProbeTrack.toneWithSilences(4410, 4410, 4410), "type", 10, 10);
			config.findTrim(0.01);
			Assert.equalsNumber(config.trimStartDuration, 100, EPSILON, "Start trim found");
			Assert.equalsNumber(config.trimEndDuration, 100, EPSILON, "End trim found");

			// A threshold above the tone makes the track fully silent: trims are reset
			config.findTrim(0.6);
			Assert.equalsNumber(config.trimStartDuration, 0, EPSILON, "Start trim reset for a silent track");
			Assert.equalsNumber(config.trimEndDuration, 0, EPSILON, "End trim reset for a silent track");
		}

		private function testSilentTracks():void
		{
			// Two blocks of the default sampling, then 30 seconds
			for each (var samplesCount:int in [2 * TrackConfiguration.SAMPLING_MIN_VALUE, 30 * 44100])
			{
				var track:ProbeTrack = ProbeTrack.fromFunction(samplesCount, function(i:int):Number { return 0; });
				var config:TrackConfiguration = new TrackConfiguration(track, "type");
				Assert.equalsNumber(config.findStartTrimDuration(0.01), track.length, EPSILON, "Start trim of a silent track of " + samplesCount + " samples");
				Assert.equalsNumber(config.findEndTrimDuration(0.01, track.length), track.length, EPSILON, "End trim of a silent track of " + samplesCount + " samples");
			}

			Assert.throws(ArgumentError, function():void
			{
				new TrackConfiguration(ProbeTrack.fromFunction(4410, function(i:int):Number { return 0; }), "type", -1, -1);
			}, "Automatic trims of a silent track");
		}

		private function testClone():void
		{
			var config:TrackConfiguration = new TrackConfiguration(ProbeTrack.tone(1000), "type", 100, 200, 4096);
			config.baseVolume = 0.4;
			var clone:TrackConfiguration = config.clone();
			Assert.isFalse(clone == config, "Clone is a new object");
			Assert.isTrue(clone.track == config.track, "Cloned track");
			Assert.isTrue(clone.type == config.type, "Cloned type");
			Assert.equalsNumber(clone.trimStartDuration, 100, EPSILON, "Cloned start trim");
			Assert.equalsNumber(clone.trimEndDuration, 200, EPSILON, "Cloned end trim");
			Assert.equalsInt(clone.sampling, 4096, "Cloned sampling");
			Assert.equalsNumber(clone.baseVolume, 0.4, EPSILON, "Cloned base volume");
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
