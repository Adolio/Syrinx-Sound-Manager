// =================================================================================================
//
//	Syrinx - Sound Manager
//	Copyright (c) 2019-2026 Aurelien Da Campo (Adolio), All Rights Reserved.
//
//	This program is free software. You can redistribute and/or modify it
//	in accordance with the terms of the accompanying license agreement.
//
// =================================================================================================

package ch.adolio.test
{
	import flash.utils.clearTimeout;
	import flash.utils.setTimeout;

	public class TestsRunner
	{
		/** Duration after which an asynchronous test which did not report its result fails, in milliseconds. */
		public var asyncTestTimeout:int = 10000;

		private var _tests:Vector.<ITest> = new Vector.<ITest>();
		private var _testsAsync:Vector.<ITestAsync> = new Vector.<ITestAsync>();

		public function addTest(test:ITest):void
		{
			_tests.push(test);
		}

		public function addTestAsync(testAsync:ITestAsync):void
		{
			_testsAsync.push(testAsync);
		}

		public function runTests():TestsResult
		{
			var testsResult:TestsResult = new TestsResult();

			for each (var test:ITest in _tests)
			{
				try
				{
					trace("Running test: " + test);
					test.execute();
					trace("Test succeeded.");
					trace("");

					testsResult.results.push(new TestResult(test + "", true, null));
				}
				catch (error:Error)
				{
					trace("Test failed. Error: " + error.getStackTrace());
					trace("");
					testsResult.results.push(new TestResult(test + "", false, error));
				}
			}

			return testsResult;
		}

		/**
		 * Runs the asynchronous tests one after the other.
		 *
		 * <p>`onComplete` prototype: `function(testsResult:TestsResult):void`</p>
		 */
		public function runTestsAsync(onComplete:Function):void
		{
			runNextTestAsync(0, new TestsResult(), onComplete);
		}

		private function runNextTestAsync(index:int, testsResult:TestsResult, onComplete:Function):void
		{
			if (index >= _testsAsync.length)
			{
				onComplete(testsResult);
				return;
			}

			var testAsync:ITestAsync = _testsAsync[index];
			var isDone:Boolean = false;
			var timeoutId:uint;

			// Records the result once, whether it comes from the test, an error or the timeout
			var finish:Function = function(error:Error):void
			{
				if (isDone)
					return;

				isDone = true;
				clearTimeout(timeoutId);

				if (error)
				{
					trace("Test failed. Error: " + error.getStackTrace());
					trace("");
					testsResult.results.push(new TestResult(testAsync + "", false, error));
				}
				else
				{
					trace("Test succeeded.");
					trace("");
					testsResult.results.push(new TestResult(testAsync + "", true, null));
				}

				runNextTestAsync(index + 1, testsResult, onComplete);
			};

			trace("Running async test: " + testAsync);
			timeoutId = setTimeout(function():void
			{
				finish(new Error("Timed out after " + asyncTestTimeout + " ms."));
			}, asyncTestTimeout);

			try
			{
				testAsync.executeAsync(function():void { finish(null); }, function(error:Error):void { finish(error); });
			}
			catch (error:Error)
			{
				finish(error);
			}
		}
	}
}
