/** \file
 * While the C runtime does not need to model the state of
 * multiple lexers and parsers in the same way as the Java runtime does
 * it is no overhead to reflect that model. In fact the
 * C runtime has always been able to share recognizer state.
 *
 * This 'class' therefore defines all the elements of a recognizer
 * (either lexer, parser or tree parser) that are need to
 * track the current recognition state. Multiple recognizers
 * may then share this state, for instance when one grammar
 * imports another.
 */

#ifndef	_ANTLR3_RECOGNIZER_SHARED_STATE_H
#define	_ANTLR3_RECOGNIZER_SHARED_STATE_H

#include    <antlr3defs.h>

/** All the data elements required to track the current state
 *  of any recognizer (lexer, parser, tree parser).
 * May be share between multiple recognizers such that 
 * grammar inheritance is easily supported.
 */
typedef	struct ANTLR3_RECOGNIZER_SHARED_STATE_struct
{



    /** If set to ANTLR3_TRUE then the recognizer has an exception
     * condition (this is tested by the generated code for the rules of
     * the grammar).
     */
    ANTLR3_BOOLEAN	    error;

    /** Points to the first in a possible chain of exceptions that the
     *  recognizer has discovered.
     */
    pANTLR3_EXCEPTION	    exception;

    /** Track around a hint from the creator of the recognizer as to how big this
     *  thing is going to get, as the actress said to the bishop. This allows us
     *  to tune hash tables accordingly. This might not be the best place for this
     *  in the end but we will see.
     */
    ANTLR3_UINT32	sizeHint;

    /** Track the set of token types that can follow any rule invocation.
     *  Stack structure, to support: List<BitSet>.
     */
    pANTLR3_STACK	following;

    /** Following stack tracker saves time by knowing which follow set we are
     *  using.
     */
    ANTLR3_INT64	_fsp;

    /** This is true when we see an error and before having successfully
     *  matched a token.  Prevents generation of more than one error message
     *  per error.
     */
    ANTLR3_BOOLEAN	errorRecovery;
    
    /** The index into the input stream where the last error occurred.
     * 	This is used to prevent infinite loops where an error is found
     *  but no token is consumed during recovery...another error is found,
     *  ad nauseam.  This is a failsafe mechanism to guarantee that at least
     *  one token/tree node is consumed for two errors.
     */
    ANTLR3_INT64	lastErrorIndex;

    /** In lieu of a return value, this indicates that a rule or token
     *  has failed to match.  Reset to false upon valid token match.
     */
    ANTLR3_BOOLEAN	failed;

    /** When the recognizer terminates, the error handling functions
     *  will have incremented this value if any error occurred (that was displayed). It can then be
     *  used by the grammar programmer without having to use static globals.
     */
    ANTLR3_UINT32	errorCount;

    /** If 0, no backtracking is going on.  Safe to exec actions etc...
     *  If >0 then it's the level of backtracking.
     */
    ANTLR3_INT32	backtracking;

    /** ANTLR3_VECTOR of ANTLR3_LIST for rule memoizing.
     *  Tracks  the stop token index for each rule.  ruleMemo[ruleIndex] is
     *  the memoization table for ruleIndex.  For key ruleStartIndex, you
     *  get back the stop token for associated rule or MEMO_RULE_FAILED.
     *
     *  This is only used if rule memoization is on.
     */
    pANTLR3_INT_TRIE	ruleMemo;

    /** Pointer to an array of token names
     *  that are generally useful in error reporting. The generated parsers install
     *  this pointer. The table it points to is statically allocated as 8 bit ascii
     *  at parser compile time - grammar token names are thus restricted in character
     *  sets, which does not seem to terrible.
     */
    pANTLR3_UINT8	* tokenNames;

    /** User programmable pointer that can be used for instance as a place to
     *  store some tracking structure specific to the grammar that would not normally
     *  be available to the error handling functions.
     */
    void		* userp;

	    /** The goal of all lexer rules/methods is to create a token object.
     *  This is an instance variable as multiple rules may collaborate to
     *  create a single token.  For example, NUM : INT | FLOAT ;
     *  In this case, you want the INT or FLOAT rule to set token and not
     *  have it reset to a NUM token in rule NUM.
     */
    pANTLR3_COMMON_TOKEN	token;

    /** The goal of all lexer rules being to create a token, then a lexer
     *  needs to build a token factory to create them.
     */
    pANTLR3_TOKEN_FACTORY	tokFactory;

    /** A lexer is a source of tokens, produced by all the generated (or
     *  hand crafted if you like) matching rules. As such it needs to provide
     *  a token source interface implementation.
     */
    pANTLR3_TOKEN_SOURCE	tokSource;

    /** The channel number for the current token
     */
    ANTLR3_UINT32		channel;

    /** The token type for the current token
     */
    ANTLR3_UINT32		type;
    
    /** The input line (where it makes sense) on which the first character of the current
     *  token resides.
     */
    ANTLR3_INT64		tokenStartLine;

    /** The character position of the first character of the current token
     *  within the line specified by tokenStartLine
     */
    ANTLR3_INT32		tokenStartCharPositionInLine;

    /** What character index in the stream did the current token start at?
     *  Needed, for example, to get the text for current token.  Set at
     *  the start of nextToken.
     */
    ANTLR3_INT64		tokenStartCharIndex;

    /** Text for the current token. This can be overridden by setting this 
     *  variable directly or by using the SETTEXT() macro (preffered) in your
     *  lexer rules.
     */
    pANTLR3_STRING		text;

	/** User controlled variables that will be installed in a newly created
	 * token.
	 */
	ANTLR3_UINT32		user1, user2, user3;
	void				* custom;

    /** Input stream stack, which allows the C programmer to switch input streams 
     *  easily and allow the standard nextToken() implementation to deal with it
     *  as this is a common requirement.
     */
    pANTLR3_STACK		streams;

}
	ANTLR3_RECOGNIZER_SHARED_STATE;

#endif