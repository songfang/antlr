/*
[The "BSD licence"]
Copyright (c) 2005-2007 Kunle Odutola
All rights reserved.

Redistribution and use in source and binary forms, with or without
modification, are permitted provided that the following conditions
are met:
1. Redistributions of source code MUST RETAIN the above copyright
   notice, this list of conditions and the following disclaimer.
2. Redistributions in binary form MUST REPRODUCE the above copyright
   notice, this list of conditions and the following disclaimer in 
   the documentation and/or other materials provided with the 
   distribution.
3. The name of the author may not be used to endorse or promote products
   derived from this software without specific prior WRITTEN permission.
4. Unless explicitly state otherwise, any contribution intentionally 
   submitted for inclusion in this work to the copyright owner or licensor
   shall be under the terms and conditions of this license, without any 
   additional terms or conditions.

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


namespace Antlr.Runtime.Tree
{
	using System;
	using IToken = Antlr.Runtime.IToken;
	
	/// <summary>
	/// A record of the rules used to Match a token sequence.  The tokens
	/// end up as the leaves of this tree and rule nodes are the interior nodes.
	/// This really adds no functionality, it is just an alias for CommonTree
	/// that is more meaningful (specific) and holds a String to display for a node.
	/// </summary>
	public class ParseTree : BaseTree
	{
		public object payload;
		public ParseTree(object label)
		{
			this.payload = label;
		}
		
		override public int Type
		{
			get { return 0; }
		}

		override public string Text
		{
			get { return ToString(); }
		}

		override public int TokenStartIndex
		{
			get { return 0; }
			set { ;         }
		}

		override public int TokenStopIndex
		{
			get { return 0; }
			set { ;         }
		}

		public override ITree DupNode()
		{
			return null;
		}
		
		public override string ToString()
		{
			if ( payload is IToken ) 
			{
				IToken t = (IToken)payload;
				if ( t.Type == Token.EOF ) 
				{
					return "<EOF>";
				}
				return t.Text;
			}
			return payload.ToString();
		}
	}
}