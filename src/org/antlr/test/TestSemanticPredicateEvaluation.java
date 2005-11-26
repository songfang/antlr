/*
[The "BSD licence"]
Copyright (c) 2005 Terence Parr
All rights reserved.

Redistribution and use in source and binary forms, with or without
modification, are permitted provided that the following conditions
are met:
1. Redistributions of source code must retain the above copyright
notice, this list of conditions and the following disclaimer.
2. Redistributions in binary form must reproduce the above copyright
notice, this list of conditions and the following disclaimer in the
documentation and/or other materials provided with the distribution.
3. The name of the author may not be used to endorse or promote products
derived from this software without specific prior written permission.

THIS SOFTWARE IS PROVIDED BY THE AUTHOR ``AS IS'' AND ANY EXPRESS OR
IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES
OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED.
IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR ANY DIRECT, INDIRECT,
INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT
NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
(INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF
THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
*/
package org.antlr.test;

import org.antlr.test.unit.TestSuite;

public class TestSemanticPredicateEvaluation extends TestSuite {
	public void testSimpleCyclicDFAWithPredicate() throws Exception {
		String grammar =
			"grammar foo;\n" +
			"a :         'x'* 'y' {System.out.println(\"alt1\");}\n" +
			"  | {true}? 'x'* 'y' {System.out.println(\"alt2\");}\n" +
			"  ;\n" ;
		String found =
			TestCompileAndExecSupport.execParser("foo.g", grammar, "foo", "fooLexer",
												 "a", "xxxy", false);
		String expecting = "alt2\n";
		assertEqual(found, expecting);
	}

	public void testSimpleCyclicDFAWithInstanceVarPredicate() throws Exception {
		String grammar =
			"grammar foo;\n" +
			"@members {boolean v=true;}\n" +
			"a :      'x'* 'y' {System.out.println(\"alt1\");}\n" +
			"  | {v}? 'x'* 'y' {System.out.println(\"alt2\");}\n" +
			"  ;\n" ;
		String found =
			TestCompileAndExecSupport.execParser("foo.g", grammar, "foo", "fooLexer",
												 "a", "xxxy", false);
		String expecting = "alt2\n";
		assertEqual(found, expecting);
	}

	public void testPredicateValidation() throws Exception {
		String grammar =
			"grammar foo;\n" +
			"@members {\n" +
			"public void reportError(RecognitionException e) {\n" +
			"    System.out.println(\"error: \"+e.toString());\n" +
			"}\n" +
			"}\n" +
			"\n" +
			"a : {false}? 'x'\n" +
			"  ;\n" ;
		String found =
			TestCompileAndExecSupport.execParser("foo.g", grammar, "foo", "fooLexer",
												 "a", "x", false);
		String expecting = "error: FailedPredicateException(a,{false}?)\n";
		assertEqual(found, expecting);
	}

	// S U P P O R T

	public void _test() throws Exception {
		String grammar =
			"grammar T;\n" +
			"options {output=AST;}\n" +
			"a :  ;\n" +
			"ID : 'a'..'z'+ ;\n" +
			"INT : '0'..'9'+;\n" +
			"WS : (' '|'\\n') {channel=99;} ;\n";
		String found =
			TestCompileAndExecSupport.execParser("t.g", grammar, "T", "TLexer",
												 "a", "abc 34", false);
		String expecting = "\n";
		assertEqual(found, expecting);
	}

}
