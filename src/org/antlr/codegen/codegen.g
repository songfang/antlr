header {
/*
 [The "BSD licence"]
 Copyright (c) 2005-2006 Terence Parr
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
	package org.antlr.codegen;
    import org.antlr.tool.*;
    import org.antlr.analysis.*;
    import org.antlr.misc.*;
	import java.util.*;
	import org.antlr.stringtemplate.*;
    import antlr.TokenWithIndex;
    import antlr.CommonToken;
}

/** Walk a grammar and generate code by gradually building up
 *  a bigger and bigger StringTemplate.
 *
 *  Terence Parr
 *  University of San Francisco
 *  June 15, 2004
 */
class CodeGenTreeWalker extends TreeParser;

options {
    // warning! ANTLR cannot see another directory to get vocabs, so I had
    // to copy the ANTLRTokenTypes.txt file into this dir from ../tools!
    // Yuck!  If you modify ../tools/antlr.g, make sure to copy the vocab here.
	importVocab = ANTLR;
    codeGenBitsetTestThreshold=999;
    ASTLabelType=GrammarAST;
}

{
	protected static final int RULE_BLOCK_NESTING_LEVEL = 0;
	protected static final int OUTER_REWRITE_NESTING_LEVEL = 0;

    protected String currentRuleName = null;
    protected int blockNestingLevel = 0;
    protected int rewriteBlockNestingLevel = 0;
	protected int outerAltNum = 0;
    protected StringTemplate currentBlockST = null;
    protected boolean currentAltHasASTRewrite = false;
    protected int rewriteTreeNestingLevel = 0;
    protected Set rewriteRuleRefs = null;

    public void reportError(RecognitionException ex) {
		Token token = null;
		if ( ex instanceof MismatchedTokenException ) {
			token = ((MismatchedTokenException)ex).token;
		}
		else if ( ex instanceof NoViableAltException ) {
			token = ((NoViableAltException)ex).token;
		}
        ErrorManager.syntaxError(
            ErrorManager.MSG_SYNTAX_ERROR,
            grammar,
            token,
            "codegen: "+ex.toString(),
            ex);
    }

    public void reportError(String s) {
        System.out.println("codegen: error: " + s);
    }

    protected CodeGenerator generator;
    protected Grammar grammar;
    protected StringTemplateGroup templates;

    /** The overall lexer/parser template; simulate dynamically scoped
     *  attributes by making this an instance var of the walker.
     */
    protected StringTemplate recognizerST;

    protected StringTemplate outputFileST;
    protected StringTemplate headerFileST;

    protected String outputOption = "";

	protected StringTemplate getWildcardST(GrammarAST elementAST, GrammarAST ast_suffix, String label) {
		String name = "wildcard";
		if ( grammar.type==Grammar.LEXER ) {
			name = "wildcardChar";
		}
		return getTokenElementST(name, name, elementAST, ast_suffix, label);
	}

	protected StringTemplate getRuleElementST(String name,
										      String elementName,
											  GrammarAST elementAST,
    										  GrammarAST ast_suffix,
    										  String label)
	{
		String suffix = getSTSuffix(ast_suffix,label);
		name += suffix;
		// if we're building trees and there is no label, gen a label
		// unless we're in a synpred rule.
		Rule r = grammar.getRule(currentRuleName);
		if ( (grammar.buildAST()||suffix.length()>0) && label==null &&
		     (r==null || !r.isSynPred) )
		{
			// we will need a label to do the AST or tracking, make one
			label = generator.createUniqueLabel(elementName);
			CommonToken labelTok = new CommonToken(ANTLRParser.ID, label);
			grammar.defineRuleRefLabel(currentRuleName, labelTok, elementAST);
		}
		StringTemplate elementST = templates.getInstanceOf(name);
		if ( label!=null ) {
			elementST.setAttribute("label", label);
		}
		return elementST;
	}

	protected StringTemplate getTokenElementST(String name,
											   String elementName,
											   GrammarAST elementAST,
											   GrammarAST ast_suffix,
											   String label)
	{
		String suffix = getSTSuffix(ast_suffix,label);
		name += suffix;
		// if we're building trees and there is no label, gen a label
		// unless we're in a synpred rule.
		Rule r = grammar.getRule(currentRuleName);
		if ( (grammar.buildAST()||suffix.length()>0) && label==null &&
		     (r==null || !r.isSynPred) )
		{
			label = generator.createUniqueLabel(elementName);
			CommonToken labelTok = new CommonToken(ANTLRParser.ID, label);
			grammar.defineTokenRefLabel(currentRuleName, labelTok, elementAST);
		}
		StringTemplate elementST = templates.getInstanceOf(name);
		if ( label!=null ) {
			elementST.setAttribute("label", label);
		}
		return elementST;
	}

	/** Return a non-empty template name suffix if the token is to be
	 *  tracked, added to a tree, or both.
	 */
	protected String getSTSuffix(GrammarAST ast_suffix, String label) {
		if ( grammar.type==Grammar.LEXER ) {
			return "";
		}
		// handle list label stuff; make element use "Track"
		boolean hasListLabel=false;
		if ( label!=null ) {
			Rule r = grammar.getRule(currentRuleName);
			String stName = null;
			if ( r!=null ) {
				Grammar.LabelElementPair pair = r.getLabel(label);
				if ( pair!=null &&
					 (pair.type==Grammar.TOKEN_LIST_LABEL||
					  pair.type==Grammar.RULE_LIST_LABEL) )
				{
					hasListLabel=true;
				}
			}
		}

		String astPart = "";
		String operatorPart = "";
		String rewritePart = "";
		String listLabelPart = "";
		if ( grammar.buildAST() ) {
			astPart = "AST";
		}
		if ( ast_suffix!=null ) {
			if ( ast_suffix.getType()==ANTLRParser.ROOT ) {
    			operatorPart = "RuleRoot";
    		}
    		else if ( ast_suffix.getType()==ANTLRParser.BANG ) {
    			operatorPart = "Bang";
    		}
   		}
		if ( currentAltHasASTRewrite ) {
			rewritePart = "Track";
		}
		if ( hasListLabel ) {
			listLabelPart = "AndListLabel";
		}
		String STsuffix = operatorPart+rewritePart+listLabelPart;
		//System.out.println("suffix = "+STsuffix);

    	return STsuffix;
	}

    protected void init(Grammar g) {
        this.grammar = g;
        this.generator = grammar.getCodeGenerator();
        this.templates = generator.getTemplates();
    }
}

grammar[Grammar g,
        StringTemplate recognizerST,
        StringTemplate outputFileST,
        StringTemplate headerFileST]
{
    init(g);
    this.recognizerST = recognizerST;
    this.outputFileST = outputFileST;
    this.headerFileST = headerFileST;
    String superClass = (String)g.getOption("superClass");
    outputOption = (String)g.getOption("output");
    recognizerST.setAttribute("superClass", superClass);
    if ( g.type!=Grammar.LEXER ) {
		recognizerST.setAttribute("ASTLabelType", g.getOption("ASTLabelType"));
	}
    if ( g.type==Grammar.TREE_PARSER && g.getOption("ASTLabelType")==null ) {
		ErrorManager.grammarWarning(ErrorManager.MSG_MISSING_AST_TYPE_IN_TREE_GRAMMAR,
								   g,
								   null,
								   g.name);
	}
    if ( g.type!=Grammar.TREE_PARSER ) {
		recognizerST.setAttribute("labelType", g.getOption("TokenLabelType"));
	}
	recognizerST.setAttribute("numRules", grammar.getRules().size());
	outputFileST.setAttribute("numRules", grammar.getRules().size());
	headerFileST.setAttribute("numRules", grammar.getRules().size());
}
    :   ( #( LEXER_GRAMMAR grammarSpec )
	    | #( PARSER_GRAMMAR grammarSpec )
	    | #( TREE_GRAMMAR grammarSpec
	       )
	    | #( COMBINED_GRAMMAR grammarSpec )
	    )
    ;

attrScope
	:	#( "scope" ID ACTION )
	;

grammarSpec
	:   name:ID
		(cmt:DOC_COMMENT
		 {
		 outputFileST.setAttribute("docComment", #cmt.getText());
		 headerFileST.setAttribute("docComment", #cmt.getText());
		 }
		)?
		{
		String suffix = Grammar.grammarTypeToFileNameSuffix[grammar.type];
        String n = #name.getText()+suffix;
		recognizerST.setAttribute("name", n);
		outputFileST.setAttribute("name", n);
		headerFileST.setAttribute("name", n);
		recognizerST.setAttribute("scopes", grammar.getGlobalScopes());
		headerFileST.setAttribute("scopes", grammar.getGlobalScopes());
		}
		( #(OPTIONS .) )?
		( #(TOKENS .) )?
        (attrScope)*
        (AMPERSAND)*
		rules[recognizerST]
	;

rules[StringTemplate recognizerST]
{
StringTemplate rST;
}
    :   (	(	{
    			String ruleName = _t.getFirstChild().getText();
    			Rule r = grammar.getRule(ruleName);
    			}
     		:
     			// if synpred, only gen if used in a DFA
    			{!r.isSynPred || grammar.synPredNamesUsedInDFA.contains(ruleName)}?
    			rST=rule
				{
				if ( rST!=null ) {
					recognizerST.setAttribute("rules", rST);
					outputFileST.setAttribute("rules", rST);
					headerFileST.setAttribute("rules", rST);
				}
				}
    		|	RULE
    		)
   		)+
    ;

rule returns [StringTemplate code=null]
{
    String r;
    String initAction = null;
    StringTemplate b;
	// get the dfa for the BLOCK
    GrammarAST block=#rule.getFirstChildWithType(BLOCK);
    DFA dfa=block.getLookaheadDFA();
	// init blockNestingLevel so it's block level RULE_BLOCK_NESTING_LEVEL
	// for alts of rule
	blockNestingLevel = RULE_BLOCK_NESTING_LEVEL-1;
	Rule ruleDescr = grammar.getRule(#rule.getFirstChild().getText());

	// For syn preds, we don't want any AST code etc... in there.
	// Save old templates ptr and restore later.  Base templates include Dbg.
	StringTemplateGroup saveGroup = templates;
	if ( ruleDescr.isSynPred ) {
		templates = generator.getBaseTemplates();
	}
}
    :   #( RULE id:ID {r=#id.getText(); currentRuleName = r;}
		    (mod:modifier)?
            #(ARG (ARG_ACTION)?)
            #(RET (ARG_ACTION)?)
			( #(OPTIONS .) )?
			(ruleScopeSpec)?
		    (AMPERSAND)*
            b=block["ruleBlock", dfa]
			{
			String description =
				grammar.grammarTreeToString(#rule.getFirstChildWithType(BLOCK),
                                            false);
			description =
                generator.target.getTargetStringLiteralFromString(description);
			b.setAttribute("description", description);
			// do not generate lexer rules in combined grammar
			String stName = null;
			if ( ruleDescr.isSynPred ) {
				stName = "synpredRule";
			}
			else if ( grammar.type==Grammar.LEXER ) {
				if ( r.equals(Grammar.ARTIFICIAL_TOKENS_RULENAME) ) {
					stName = "tokensRule";
				}
				else {
					stName = "lexerRule";
				}
			}
			else {
				if ( !(grammar.type==Grammar.COMBINED &&
					 Character.isUpperCase(r.charAt(0))) )
				{
					stName = "rule";
				}
			}
			code = templates.getInstanceOf(stName);
			if ( code.getName().equals("rule") ) {
				code.setAttribute("emptyRule",
					Boolean.valueOf(grammar.isEmptyRule(block)));
			}
			code.setAttribute("ruleDescriptor", ruleDescr);
			String memo = (String)#rule.getOption("memoize");
			if ( memo==null ) {
				memo = (String)grammar.getOption("memoize");
			}
			if ( memo!=null && memo.equals("true") &&
			     (stName.equals("rule")||stName.equals("lexerRule")) )
			{
            	code.setAttribute("memoize",
            		Boolean.valueOf(memo!=null && memo.equals("true")));
            }
			}

	     	(exceptionGroup[code])?
	     	EOR
         )
        {
        if ( code!=null ) {
			if ( grammar.type==Grammar.LEXER ) {
		    	boolean naked =
		    		r.equals(Grammar.ARTIFICIAL_TOKENS_RULENAME) ||
		    	    (mod!=null&&mod.getText().equals(Grammar.FRAGMENT_RULE_MODIFIER));
		    	code.setAttribute("nakedBlock", Boolean.valueOf(naked));
			}
			else {
				description =
					grammar.grammarTreeToString(#rule,false);
				description =
				    generator.target.getTargetStringLiteralFromString(description);
				code.setAttribute("description", description);
			}
			Rule theRule = grammar.getRule(r);
			generator.translateActionAttributeReferencesForSingleScope(
				theRule,
				theRule.getActions()
			);
			code.setAttribute("ruleName", r);
			code.setAttribute("block", b);
			if ( initAction!=null ) {
				code.setAttribute("initAction", initAction);
			}
        }
		templates = saveGroup;
        }
    ;

modifier
	:	"protected"
	|	"public"
	|	"private"
	|	"fragment"
	;

ruleScopeSpec
 	:	#( "scope" (ACTION)? ( ID )* )
 	;

block[String blockTemplateName, DFA dfa]
     returns [StringTemplate code=null]
{
    StringTemplate decision = null;
    if ( dfa!=null ) {
        code = templates.getInstanceOf(blockTemplateName);
        decision = generator.genLookaheadDecision(recognizerST,dfa);
        code.setAttribute("decision", decision);
        code.setAttribute("decisionNumber", dfa.getDecisionNumber());
		code.setAttribute("maxK",dfa.getMaxLookaheadDepth());
		code.setAttribute("maxAlt",dfa.getNumberOfAlts());
    }
    else {
        code = templates.getInstanceOf(blockTemplateName+"SingleAlt");
    }
    blockNestingLevel++;
    code.setAttribute("blockLevel", blockNestingLevel);
    code.setAttribute("enclosingBlockLevel", blockNestingLevel-1);
    StringTemplate alt = null;
    StringTemplate rew = null;
    StringTemplate sb = null;
    GrammarAST r = null;
    int altNum = 1;
	if ( this.blockNestingLevel==RULE_BLOCK_NESTING_LEVEL ) {
        this.outerAltNum=1;
    }
}
    :   {#block.getSetValue()!=null}? sb=setBlock
        {
            code.setAttribute("alts",sb);
            blockNestingLevel--;
        }

    |   #(  BLOCK
    	    ( OPTIONS )? // ignore
            ( alt=alternative {r=(GrammarAST)_t;} rew=rewrite
              {
              if ( this.blockNestingLevel==RULE_BLOCK_NESTING_LEVEL ) {
              	this.outerAltNum++;
              }
              // add the rewrite code as just another element in the alt :)
    		  if ( rew!=null ) {
    		  	alt.setAttribute("elements.{el,line,pos}",
    		  		rew, Utils.integer(r.getLine()), Utils.integer(r.getColumn()));
    		  }
    		  // add this alt to the list of alts for this block
              code.setAttribute("alts",alt);
              alt.setAttribute("altNum", Utils.integer(altNum));
              alt.setAttribute("outerAlt",
                  Boolean.valueOf(blockNestingLevel==RULE_BLOCK_NESTING_LEVEL));
              altNum++;
              }
            )+
            EOB
         )
    	{blockNestingLevel--;}
    ;

setBlock returns [StringTemplate code=null]
{
if ( blockNestingLevel==RULE_BLOCK_NESTING_LEVEL && grammar.buildAST() ) {
    Rule r = grammar.getRule(currentRuleName);
    currentAltHasASTRewrite = r.hasRewrite(outerAltNum);
}
}
    :   s:BLOCK
        {
        StringTemplate setcode =
            getTokenElementST("matchSet", "set", #s, null, null);
        int i = ((TokenWithIndex)#s.getToken()).getIndex();
		setcode.setAttribute("elementIndex", i);
		if ( grammar.type!=Grammar.LEXER ) {
			generator.generateLocalFOLLOW(#s,"set",currentRuleName,i);
        }
        setcode.setAttribute("s",
            generator.genSetExpr(templates,#s.getSetValue(),1,false));
        StringTemplate altcode=templates.getInstanceOf("alt");
		altcode.setAttribute("elements.{el,line,pos}",
						     setcode,
                             Utils.integer(#s.getLine()),
                             Utils.integer(#s.getColumn())
                            );
        altcode.setAttribute("altNum", Utils.integer(1));
        altcode.setAttribute("outerAlt",
           Boolean.valueOf(blockNestingLevel==RULE_BLOCK_NESTING_LEVEL));
        if ( !currentAltHasASTRewrite && grammar.buildAST() ) {
            altcode.setAttribute("autoAST", Boolean.valueOf(true));
        }
        code = altcode;
        }
    ;

exceptionGroup[StringTemplate ruleST]
	:	( exceptionHandler[ruleST] )+ (finallyClause[ruleST])?
	|   finallyClause[ruleST]
    ;

exceptionHandler[StringTemplate ruleST]
    :    #("catch" ARG_ACTION ACTION)
    	{
    	List chunks = generator.translateAction(currentRuleName,#ACTION);
    	ruleST.setAttribute("exceptions.{decl,action}",#ARG_ACTION.getText(),chunks);
    	}
    ;

finallyClause[StringTemplate ruleST]
    :    #("finally" ACTION)
    	{
    	List chunks = generator.translateAction(currentRuleName,#ACTION);
    	ruleST.setAttribute("finally",chunks);
    	}
    ;

alternative returns [StringTemplate code=templates.getInstanceOf("alt")]
{
/*
// TODO: can we use Rule.altsWithRewrites???
if ( blockNestingLevel==RULE_BLOCK_NESTING_LEVEL ) {
	GrammarAST aRewriteNode = #alternative.findFirstType(REWRITE);
	if ( grammar.buildAST() &&
		 (aRewriteNode!=null||
		 (#alternative.getNextSibling()!=null &&
		  #alternative.getNextSibling().getType()==REWRITE)) )
	{
		currentAltHasASTRewrite = true;
	}
	else {
		currentAltHasASTRewrite = false;
	}
}
*/
if ( blockNestingLevel==RULE_BLOCK_NESTING_LEVEL && grammar.buildAST() ) {
    Rule r = grammar.getRule(currentRuleName);
    currentAltHasASTRewrite = r.hasRewrite(outerAltNum);
}
String description = grammar.grammarTreeToString(#alternative, false);
description = generator.target.getTargetStringLiteralFromString(description);
code.setAttribute("description", description);
if ( !currentAltHasASTRewrite && grammar.buildAST() ) {
	code.setAttribute("autoAST", Boolean.valueOf(true));
}
StringTemplate e;
}
    :   #(	a:ALT
    		(	{GrammarAST elAST=(GrammarAST)_t;}
    			e=element[null,null]
    			{
    			if ( e!=null ) {
					code.setAttribute("elements.{el,line,pos}",
									  e,
									  Utils.integer(elAST.getLine()),
									  Utils.integer(elAST.getColumn())
									 );
    			}
    			}
    		)+
    		EOA
    	 )
    ;

element[GrammarAST label, GrammarAST astSuffix] returns [StringTemplate code=null]
{
    IntSet elements=null;
    GrammarAST ast = null;
}
    :   #(ROOT code=element[label,#ROOT])

    |   #(BANG code=element[label,#BANG])

    |   #( n:NOT code=notElement[#n, label, astSuffix] )

    |	#( ASSIGN alabel:ID code=element[#alabel,astSuffix] )

    |	#( PLUS_ASSIGN label2:ID code=element[#label2,astSuffix] )

    |   #(CHAR_RANGE a:CHAR_LITERAL b:CHAR_LITERAL)
        {code = templates.getInstanceOf("charRangeRef");
		 String low =
		 	generator.target.getTargetCharLiteralFromANTLRCharLiteral(generator,a.getText());
		 String high =
		 	generator.target.getTargetCharLiteralFromANTLRCharLiteral(generator,b.getText());
         code.setAttribute("a", low);
         code.setAttribute("b", high);
        }

    |   {#element.getSetValue()==null}? code=ebnf

    |   code=atom[label, astSuffix]

    |   code=tree

    |   act:ACTION
        {
        code = templates.getInstanceOf("execAction");
        code.setAttribute("action", generator.translateAction(currentRuleName,#act));
        }

    |   (sp:SEMPRED|gsp:GATED_SEMPRED {#sp=#gsp;})
        {
        code = templates.getInstanceOf("validateSemanticPredicate");
        code.setAttribute("pred", generator.translateAction(currentRuleName,#sp));
		String description =
			generator.target.getTargetStringLiteralFromString(#sp.getText());
		code.setAttribute("description", description);
        }

    |	SYN_SEMPRED // used only in lookahead; don't generate validating pred

    |	BACKTRACK_SEMPRED

    |   EPSILON
    ;

notElement[GrammarAST n, GrammarAST label, GrammarAST astSuffix]
returns [StringTemplate code=null]
{
    IntSet elements=null;
    String labelText = null;
    if ( label!=null ) {
        labelText = label.getText();
    }
}
    :   (assign_c:CHAR_LITERAL
        {
        int ttype=0;
        if ( grammar.type==Grammar.LEXER ) {
            ttype = Grammar.getCharValueFromGrammarCharLiteral(assign_c.getText());
        }
        else {
            ttype = grammar.getTokenType(assign_c.getText());
        }
        elements = grammar.complement(ttype);
        }
    |   assign_s:STRING_LITERAL
        {
        int ttype=0;
        if ( grammar.type==Grammar.LEXER ) {
            // TODO: error!
        }
        else {
            ttype = grammar.getTokenType(assign_s.getText());
        }
        elements = grammar.complement(ttype);
        }
    |   assign_t:TOKEN_REF
        {
        int ttype = grammar.getTokenType(assign_t.getText());
        elements = grammar.complement(ttype);
        }
    |   assign_st:BLOCK
        {
        elements = assign_st.getSetValue();
        elements = grammar.complement(elements);
        }
        )
        {
        code = getTokenElementST("matchSet",
                                 "set",
                                 (GrammarAST)n.getFirstChild(),
                                 astSuffix,
                                 labelText);
        code.setAttribute("s",generator.genSetExpr(templates,elements,1,false));
        int i = ((TokenWithIndex)n.getToken()).getIndex();
        code.setAttribute("elementIndex", i);
        if ( grammar.type!=Grammar.LEXER ) {
            generator.generateLocalFOLLOW(n,"set",currentRuleName,i);
        }
        }
    ;

ebnf returns [StringTemplate code=null]
{
    DFA dfa=null;
    GrammarAST b = (GrammarAST)#ebnf.getFirstChild();
    GrammarAST eob = (GrammarAST)#b.getLastChild(); // loops will use EOB DFA
}
    :   (	{dfa = #ebnf.getLookaheadDFA();}
			code=block["block", dfa]
		|   {dfa = #ebnf.getLookaheadDFA();}
			#( OPTIONAL code=block["optionalBlock", dfa] )
		|   {dfa = #eob.getLookaheadDFA();}
			#( CLOSURE code=block["closureBlock", dfa] )
		|   {dfa = #eob.getLookaheadDFA();}
			#( POSITIVE_CLOSURE code=block["positiveClosureBlock", dfa] )
		)
		{
		String description = grammar.grammarTreeToString(#ebnf, false);
		description = generator.target.getTargetStringLiteralFromString(description);
    	code.setAttribute("description", description);
    	}
    ;

tree returns [StringTemplate code=templates.getInstanceOf("tree")]
{
StringTemplate el=null;
GrammarAST elAST=null;
NFAState afterDOWN = (NFAState)tree_AST_in.NFATreeDownState.transition(0).target;
LookaheadSet s = grammar.LOOK(afterDOWN);
if ( s.member(Label.UP) ) {
	// nullable child list if we can see the UP as the next token
	// we need an "if ( input.LA(1)==Token.DOWN )" gate around
	// the child list.
	code.setAttribute("nullableChildList", "true");
}
}
    :   #( TREE_BEGIN {elAST=(GrammarAST)_t;}
    	   el=element[null,null]
           {
           code.setAttribute("root.{el,line,pos}",
							  el,
							  Utils.integer(elAST.getLine()),
							  Utils.integer(elAST.getColumn())
							  );
           }
           ( {elAST=(GrammarAST)_t;}
    		 el=element[null,null]
           	 {
			 code.setAttribute("children.{el,line,pos}",
							  el,
							  Utils.integer(elAST.getLine()),
							  Utils.integer(elAST.getColumn())
							  );
			 }
           )*
         )
    ;

atom[GrammarAST label, GrammarAST astSuffix] 
    returns [StringTemplate code=null]
{
String labelText=null;
if ( label!=null ) {
    labelText = label.getText();
}
}
    :   #( r:RULE_REF (rarg:ARG_ACTION)? )
        {
        grammar.checkRuleReference(#r, #rarg, currentRuleName);
        Rule rdef = grammar.getRule(#r.getText());
        // don't insert label=r() if $label.attr not used, no ret value, ...
        if ( !rdef.getHasReturnValue() ) {
            labelText = null;
        }
        code = getRuleElementST("ruleRef", #r.getText(), #r, astSuffix, labelText);
		code.setAttribute("rule", r.getText());

		if ( #rarg!=null ) {
			List args = generator.translateAction(currentRuleName,#rarg);
			code.setAttribute("args", args);
		}
        int i = ((TokenWithIndex)r.getToken()).getIndex();
		code.setAttribute("elementIndex", i);
		generator.generateLocalFOLLOW(#r,#r.getText(),currentRuleName,i);
		#r.code = code;
        }

    |   #( t:TOKEN_REF (targ:ARG_ACTION)? )
        {
           grammar.checkRuleReference(#t, #targ, currentRuleName);
		   if ( grammar.type==Grammar.LEXER ) {
				if ( grammar.getTokenType(t.getText())==Label.EOF ) {
					code = templates.getInstanceOf("lexerMatchEOF");
				}
			    else {
					code = templates.getInstanceOf("lexerRuleRef");
					code.setAttribute("rule", t.getText());
					if ( #targ!=null ) {
						List args = generator.translateAction(currentRuleName,#targ);
						code.setAttribute("args", args);
					}
				}
			    if ( label!=null ) code.setAttribute("label", labelText);
		   }
		   else {
				code = getTokenElementST("tokenRef", #t.getText(), #t, astSuffix, labelText);
				String tokenLabel =
				   generator.getTokenTypeAsTargetLabel(grammar.getTokenType(t.getText()));
				code.setAttribute("token",tokenLabel);
                int i = ((TokenWithIndex)#t.getToken()).getIndex();
			    code.setAttribute("elementIndex", i);
			    generator.generateLocalFOLLOW(#t,tokenLabel,currentRuleName,i);
		   }
		   #t.code = code;
		}

    |   c:CHAR_LITERAL
        {
		if ( grammar.type==Grammar.LEXER ) {
			code = templates.getInstanceOf("charRef");
			code.setAttribute("char",
			   generator.target.getTargetCharLiteralFromANTLRCharLiteral(generator,c.getText()));
			if ( label!=null ) {
				code.setAttribute("label", labelText);
			}
		}
		else { // else it's a token type reference
			code = getTokenElementST("tokenRef", "char_literal", #c, astSuffix, labelText);
			String tokenLabel = generator.getTokenTypeAsTargetLabel(grammar.getTokenType(c.getText()));
			code.setAttribute("token",tokenLabel);
            int i = ((TokenWithIndex)#c.getToken()).getIndex();
			code.setAttribute("elementIndex", i);
			generator.generateLocalFOLLOW(#c,tokenLabel,currentRuleName,i);
		}
        }

    |   s:STRING_LITERAL
        {
		if ( grammar.type==Grammar.LEXER ) {
			code = templates.getInstanceOf("lexerStringRef");
			code.setAttribute("string",
			   generator.target.getTargetStringLiteralFromANTLRStringLiteral(generator,s.getText()));
			if ( label!=null ) {
				code.setAttribute("label", labelText);
			}
		}
		else { // else it's a token type reference
			code = getTokenElementST("tokenRef", "string_literal", #s, astSuffix, labelText);
			String tokenLabel =
			   generator.getTokenTypeAsTargetLabel(grammar.getTokenType(#s.getText()));
			code.setAttribute("token",tokenLabel);
            int i = ((TokenWithIndex)#s.getToken()).getIndex();
			code.setAttribute("elementIndex", i);
			generator.generateLocalFOLLOW(#s,tokenLabel,currentRuleName,i);
		}
		}

    |   w:WILDCARD
        {
		code = getWildcardST(#w,astSuffix,labelText);
		code.setAttribute("elementIndex", ((TokenWithIndex)#w.getToken()).getIndex());
		}

    |	code=set[label,astSuffix]
    ;

ast_suffix
	:	ROOT
	|	BANG
	;


set[GrammarAST label, GrammarAST astSuffix] returns [StringTemplate code=null]
{
String labelText=null;
if ( label!=null ) {
    labelText = label.getText();
}
}
	:   s:BLOCK // only care that it's a BLOCK with setValue!=null
        {
        code = getTokenElementST("matchSet", "set", #s, astSuffix, labelText);
        int i = ((TokenWithIndex)#s.getToken()).getIndex();
		code.setAttribute("elementIndex", i);
		if ( grammar.type!=Grammar.LEXER ) {
			generator.generateLocalFOLLOW(#s,"set",currentRuleName,i);
        }
        code.setAttribute("s", generator.genSetExpr(templates,#s.getSetValue(),1,false));
        }
    ;

setElement
    :   c:CHAR_LITERAL
    |   t:TOKEN_REF
    |   s:STRING_LITERAL
    |	#(CHAR_RANGE c1:CHAR_LITERAL c2:CHAR_LITERAL)
    ;

// REWRITE stuff

rewrite returns [StringTemplate code=null]
{
StringTemplate alt;
if ( #rewrite.getType()==REWRITE ) {
	if ( generator.grammar.buildTemplate() ) {
		code = templates.getInstanceOf("rewriteTemplate");
	}
	else {
		code = templates.getInstanceOf("rewriteCode");
		code.setAttribute("treeLevel", Utils.integer(OUTER_REWRITE_NESTING_LEVEL));
		code.setAttribute("rewriteBlockLevel", Utils.integer(OUTER_REWRITE_NESTING_LEVEL));
		currentBlockST = code;
	}
}
}
	:	(
			{rewriteRuleRefs = new HashSet();}
			#( r:REWRITE (pred:SEMPRED)? alt=rewrite_alternative )
			{
            rewriteBlockNestingLevel = OUTER_REWRITE_NESTING_LEVEL;
			List predChunks = null;
			if ( #pred!=null ) {
				//predText = #pred.getText();
        		predChunks = generator.translateAction(currentRuleName,#pred);
			}
			String description =
			    grammar.grammarTreeToString(#r,false);
			description = generator.target.getTargetStringLiteralFromString(description);
			code.setAttribute("alts.{pred,alt,description}",
							  predChunks,
							  alt,
							  description);
			pred=null;
			}
		)*
	;

rewrite_block[String blockTemplateName] returns [StringTemplate code=null]
{
rewriteBlockNestingLevel++;
code = templates.getInstanceOf(blockTemplateName);
StringTemplate save_currentBlockST = currentBlockST;
currentBlockST = code;
code.setAttribute("rewriteBlockLevel", rewriteBlockNestingLevel);
StringTemplate alt=null;
}
    :   #(  BLOCK
            alt=rewrite_alternative
            EOB
         )
    	{
    	code.setAttribute("alt", alt);
    	rewriteBlockNestingLevel--;
    	currentBlockST = save_currentBlockST;
    	}
    ;

rewrite_alternative
	returns [StringTemplate code=null]
{
StringTemplate el,st;
}
    :   {generator.grammar.buildAST()}?
    	#(	a:ALT {code=templates.getInstanceOf("rewriteElementList");}
			(	(	{GrammarAST elAST=(GrammarAST)_t;}
    				el=rewrite_element
					{code.setAttribute("elements.{el,line,pos}",
					 					el,
    							  		Utils.integer(elAST.getLine()),
    							  		Utils.integer(elAST.getColumn())
					 					);
					}
				)+
    		|	EPSILON
    			{code.setAttribute("elements.{el,line,pos}",
    							   templates.getInstanceOf("rewriteEmptyAlt"),
    							   Utils.integer(#a.getLine()),
    							   Utils.integer(#a.getColumn())
					 			   );
				}
    		)
    		EOA
    	 )
    |	{generator.grammar.buildTemplate()}? code=rewrite_template
    ;

rewrite_element returns [StringTemplate code=null]
{
    IntSet elements=null;
    GrammarAST ast = null;
}
    :   code=rewrite_atom[false]

    |   #(  n:NOT
            (  c:CHAR_LITERAL
            |  s:STRING_LITERAL
            |  t:TOKEN_REF
            |  #( st:SET (rewrite_setElement)+ )
            )
         )

    |   code=rewrite_ebnf

    |   code=rewrite_tree
    ;

rewrite_ebnf returns [StringTemplate code=null]
    :   #( OPTIONAL code=rewrite_block["rewriteOptionalBlock"] )
		{
		String description = grammar.grammarTreeToString(#rewrite_ebnf, false);
		description = generator.target.getTargetStringLiteralFromString(description);
		code.setAttribute("description", description);
		}
    |   #( CLOSURE code=rewrite_block["rewriteClosureBlock"] )
		{
		String description = grammar.grammarTreeToString(#rewrite_ebnf, false);
		description = generator.target.getTargetStringLiteralFromString(description);
		code.setAttribute("description", description);
		}
    |   #( POSITIVE_CLOSURE code=rewrite_block["rewritePositiveClosureBlock"] )
		{
		String description = grammar.grammarTreeToString(#rewrite_ebnf, false);
		description = generator.target.getTargetStringLiteralFromString(description);
		code.setAttribute("description", description);
		}
    ;

rewrite_tree returns [StringTemplate code=templates.getInstanceOf("rewriteTree")]
{
rewriteTreeNestingLevel++;
code.setAttribute("treeLevel", rewriteTreeNestingLevel);
code.setAttribute("enclosingTreeLevel", rewriteTreeNestingLevel-1);
StringTemplate r, el;
GrammarAST elAST=null;
}
	:   #(	TREE_BEGIN {elAST=(GrammarAST)_t;}
			r=rewrite_atom[true]
			{code.setAttribute("root.{el,line,pos}",
							   r,
							   Utils.integer(elAST.getLine()),
							   Utils.integer(elAST.getColumn())
							  );
			}
			( {elAST=(GrammarAST)_t;}
			  el=rewrite_element
			  {
			  code.setAttribute("children.{el,line,pos}",
							    el,
							    Utils.integer(elAST.getLine()),
							    Utils.integer(elAST.getColumn())
							    );
			  }
			)*
		)
		{
		String description = grammar.grammarTreeToString(#rewrite_tree, false);
		description = generator.target.getTargetStringLiteralFromString(description);
		code.setAttribute("description", description);
    	rewriteTreeNestingLevel--;
		}
    ;

rewrite_atom[boolean isRoot] returns [StringTemplate code=null]
    :   r:RULE_REF
    	{
    	String ruleRefName = #r.getText();
    	String stName = "rewriteRuleRef";
    	if ( isRoot ) {
    		stName += "Root";
    	}
    	code = templates.getInstanceOf(stName);
    	code.setAttribute("rule", ruleRefName);
    	if ( grammar.getRule(ruleRefName)==null ) {
			ErrorManager.grammarError(ErrorManager.MSG_UNDEFINED_RULE_REF,
									  grammar,
									  ((GrammarAST)(#r)).getToken(),
									  ruleRefName);
    		code = new StringTemplate(); // blank; no code gen
    	}
    	else if ( grammar.getRule(currentRuleName)
    			     .getRuleRefsInAlt(ruleRefName,outerAltNum)==null )
		{
			ErrorManager.grammarError(ErrorManager.MSG_REWRITE_ELEMENT_NOT_PRESENT_ON_LHS,
									  grammar,
									  ((GrammarAST)(#r)).getToken(),
									  ruleRefName);
    		code = new StringTemplate(); // blank; no code gen
    	}
    	else {
    		// track all rule refs as we must copy 2nd ref to rule and beyond
    		if ( !rewriteRuleRefs.contains(ruleRefName) ) {
	    		rewriteRuleRefs.add(ruleRefName);
    		}
    		else {
    			// we found a ref to the same rule in the same -> rewrite
    			code.setAttribute("dup", Boolean.valueOf(true));
    		}
			currentBlockST.setAttribute("referencedRules", ruleRefName);
		}
    	}

    |   ( #(TOKEN_REF (arg:ARG_ACTION)?) | CHAR_LITERAL | STRING_LITERAL )
    	{
    	String tokenName = #rewrite_atom.getText();
    	String stName = "rewriteTokenRef";
    	Rule rule = grammar.getRule(currentRuleName);
    	Set tokenRefsInAlt = rule.getTokenRefsInAlt(outerAltNum);
    	boolean imaginary = !tokenRefsInAlt.contains(tokenName);
    	if ( imaginary ) {
    		stName = "rewriteImaginaryTokenRef";
    	}
    	if ( isRoot ) {
    		stName += "Root";
    	}
    	code = templates.getInstanceOf(stName);
    	if ( #arg!=null ) {
			List args = generator.translateAction(currentRuleName,#arg);
			code.setAttribute("args", args);
    	}
		code.setAttribute("elementIndex", ((TokenWithIndex)#rewrite_atom.getToken()).getIndex());
		int ttype = grammar.getTokenType(tokenName);
		String tok = generator.getTokenTypeAsTargetLabel(ttype);
    	code.setAttribute("token", tok);
    	if ( grammar.getTokenType(tokenName)==Label.INVALID ) {
			ErrorManager.grammarError(ErrorManager.MSG_UNDEFINED_TOKEN_REF_IN_REWRITE,
									  grammar,
									  ((GrammarAST)(#rewrite_atom)).getToken(),
									  tokenName);
    		code = new StringTemplate(); // blank; no code gen
    	}
    	else {
    		// only track this reference if it's valid
			if ( !imaginary ) {
				currentBlockST.setAttribute("referencedTokens", tok);
			}
		}
    	}

    |	code=rewrite_set

    |	LABEL
    	{
    	String labelName = #LABEL.getText();
    	Rule rule = grammar.getRule(currentRuleName);
    	Grammar.LabelElementPair pair = rule.getLabel(labelName);
    	if ( labelName.equals(currentRuleName) ) {
    		// special case; ref to old value via $rule
    		StringTemplate labelST = templates.getInstanceOf("prevRuleRootRef");
    		code = templates.getInstanceOf("rewriteRuleLabelRef"+(isRoot?"Root":""));
    		code.setAttribute("label", labelST);
    	}
    	else if ( pair==null ) {
			ErrorManager.grammarError(ErrorManager.MSG_UNDEFINED_LABEL_REF_IN_REWRITE,
									  grammar,
									  ((GrammarAST)(#LABEL)).getToken(),
									  labelName);
			code = new StringTemplate();
    	}
    	else {
			String stName = null;
			String refListAttrName = null;
			switch ( pair.type ) {
				case Grammar.TOKEN_LABEL :
					stName = "rewriteTokenLabelRef";
					refListAttrName = "referencedTokenLabels";
					break;
				case Grammar.RULE_LABEL :
					stName = "rewriteRuleLabelRef";
					refListAttrName = "referencedRuleLabels";
					break;
				case Grammar.TOKEN_LIST_LABEL :
					stName = "rewriteTokenListLabelRef";
					refListAttrName = "referencedListLabels";
					break;
				case Grammar.RULE_LIST_LABEL :
					stName = "rewriteRuleListLabelRef";
					refListAttrName = "referencedListLabels";
					break;
			}
			if ( isRoot ) {
				stName += "Root";
			}
			code = templates.getInstanceOf(stName);
			code.setAttribute("label", labelName);
			if ( refListAttrName!=null ) {
				currentBlockST.setAttribute(refListAttrName, #LABEL.getText());
			}
		}
    	}

    |	ACTION
        {
        // actions in rewrite rules yield a tree object
        String actText = #ACTION.getText();
        List chunks = generator.translateAction(currentRuleName,#ACTION);
		code = templates.getInstanceOf("rewriteNodeAction"+(isRoot?"Root":""));
		code.setAttribute("action", chunks);
        }
    ;

rewrite_set returns [StringTemplate code=null]
	:   #( s:SET (rewrite_setElement)+ )
    ;

rewrite_setElement
    :   c:CHAR_LITERAL
    |   t:TOKEN_REF
    |   s:STRING_LITERAL
    ;

rewrite_template returns [StringTemplate code=null]
    :	#( ALT EPSILON EOA ) {code=templates.getInstanceOf("rewriteEmptyTemplate");}
   	|	#( TEMPLATE (id:ID|ind:ACTION)
		   {
		   if ( #id!=null && #id.getText().equals("template") ) {
		   		code = templates.getInstanceOf("rewriteInlineTemplate");
		   }
		   else if ( #id!=null ) {
		   		code = templates.getInstanceOf("rewriteExternalTemplate");
		   		code.setAttribute("name", #id.getText());
		   }
		   else if ( #ind!=null ) { // must be %({expr})(args)
		   		code = templates.getInstanceOf("rewriteIndirectTemplate");
				List chunks=generator.translateAction(currentRuleName,#ind);
		   		code.setAttribute("expr", chunks);
		   }
		   }
	       #( ARGLIST
	       	  ( #( ARG arg:ID a:ACTION
		   		   {
                   // must set alt num here rather than in define.g
                   // because actions like %foo(name={$ID.text}) aren't
                   // broken up yet into trees.
				   #a.outerAltNum = this.outerAltNum;
		   		   List chunks = generator.translateAction(currentRuleName,#a);
		   		   code.setAttribute("args.{name,value}", #arg.getText(), chunks);
		   		   }
	             )
	          )*
	        )
		   ( DOUBLE_QUOTE_STRING_LITERAL
             {
             String sl = #DOUBLE_QUOTE_STRING_LITERAL.getText();
			 String t = sl.substring(1,sl.length()-1); // strip quotes
			 t = generator.target.getTargetStringLiteralFromString(t);
             code.setAttribute("template",t);
             }
		   | DOUBLE_ANGLE_STRING_LITERAL
             {
             String sl = #DOUBLE_ANGLE_STRING_LITERAL.getText();
			 String t = sl.substring(2,sl.length()-2); // strip double angle quotes
			 t = generator.target.getTargetStringLiteralFromString(t);
             code.setAttribute("template",t);
             }
		   )?
	     )

	|	act:ACTION
   		{
        // set alt num for same reason as ARGLIST above
        #act.outerAltNum = this.outerAltNum;
   		code=templates.getInstanceOf("rewriteAction");
   		code.setAttribute("action",
   						  generator.translateAction(currentRuleName,#act));
   		}
	;
