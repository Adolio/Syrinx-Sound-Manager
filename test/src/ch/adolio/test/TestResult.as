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
	public class TestResult
	{
		public var testName:String;
		public var success:Boolean;
		public var error:Error;

		public function TestResult(testName:String, success:Boolean, error:Error)
		{
			this.testName = testName;
			this.success = success;
			this.error = error;
		}
	}
}
