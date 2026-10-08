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
	import ch.adolio.test.TestResult;
	import ch.adolio.test.TestsResult;
	import ch.adolio.test.TestsRunner;
	import flash.desktop.NativeApplication;
	import flash.display.Sprite;

	/**
	 * Runs the synchronous tests, then the asynchronous ones, then exits with code 1 if a test failed, 0 otherwise.
	 */
	public class TestMain extends Sprite
	{
		private var _testsRunner:TestsRunner = new TestsRunner();

		public function TestMain()
		{
			setupTests();

			var testsResult:TestsResult = _testsRunner.runTests();
			_testsRunner.runTestsAsync(function(asyncTestsResult:TestsResult):void
			{
				for each (var result:TestResult in asyncTestsResult.results)
					testsResult.results.push(result);

				printResults(testsResult);
				NativeApplication.nativeApplication.exit(testsResult.failedTestsCount > 0 ? 1 : 0);
			});
		}

		private function setupTests():void
		{
			// Synchronous tests
			_testsRunner.addTest(new WavTrackTest());
			_testsRunner.addTest(new TrackConfigurationTest());
			_testsRunner.addTest(new TrackRegistrationTest());
			_testsRunner.addTest(new SoundInstanceTest());
			_testsRunner.addTest(new PoolTest());
			_testsRunner.addTest(new PlaybackTest());

			// Asynchronous tests
			_testsRunner.addTestAsync(new CompletionTestAsync());
			_testsRunner.addTestAsync(new PitchTestAsync());
		}

		private function printResults(testsResult:TestsResult):void
		{
			trace("----------------------------");
			var failedTestsCount:uint = testsResult.failedTestsCount;
			if (failedTestsCount > 0)
				trace(failedTestsCount + " / " + testsResult.results.length + " test(s) failed.");
			else
				trace("All " + testsResult.results.length + " test(s) passed.");
		}
	}
}
