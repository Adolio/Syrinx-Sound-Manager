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
	public class TestsResult
	{
		public var results:Vector.<TestResult> = new Vector.<TestResult>();

		public function get failedTestsCount():uint
		{
			var failedTests:uint = 0;
			for each (var result:TestResult in results)
			{
				if (!result.success)
					failedTests++;
			}

			return failedTests;
		}
	}
}
