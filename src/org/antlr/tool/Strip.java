package org.antlr.tool;

import org.antlr.grammar.v3.ANTLRv3Lexer;
import org.antlr.grammar.v3.ANTLRv3Parser;
import org.antlr.runtime.*;
import org.antlr.runtime.tree.CommonTree;
import org.antlr.runtime.tree.TreeAdaptor;
import org.antlr.runtime.tree.TreeWizard;

import java.util.List;

/** A basic action stripper. */
public class Strip {
    public static void main(String args[]) throws Exception {
        CharStream input = null;
        String inputName = "<stdin>";
        if ( args.length==1 ) {
            input = new ANTLRFileStream(args[0]);
            inputName = args[0];
        }
        else {
            input = new ANTLRInputStream(System.in);
        }

        // BUILD AST
        ANTLRv3Lexer lex = new ANTLRv3Lexer(input);
        final TokenRewriteStream tokens = new TokenRewriteStream(lex);
        ANTLRv3Parser g = new ANTLRv3Parser(tokens);
        ANTLRv3Parser.grammarDef_return r = g.grammarDef();
        CommonTree t = (CommonTree)r.getTree();
        //System.out.println(t.toStringTree());

        final TreeAdaptor adaptor = g.getTreeAdaptor();
        TreeWizard wiz = new TreeWizard(adaptor, g.getTokenNames());
        //CommonTree t = (CommonTree)wiz.create("(A B C (A[foo] B[bar]) (D (A[big] B[dog])))");

        // ACTIONS STUFF
        wiz.visit(t, ANTLRv3Parser.ACTION,
           new TreeWizard.Visitor() {
               public void visit(Object t) { ACTION(tokens, (CommonTree)t); }
           });

        wiz.visit(t, ANTLRv3Parser.AT,  // ^('@' id ACTION) rule actions
            new TreeWizard.Visitor() {
              public void visit(Object t) {
                  CommonTree a = (CommonTree)t;
                  if ( a.getChildCount()>=2 ) {
                      CommonTree action = (CommonTree)a.getChild(1);
                      if ( action.getType()==ANTLRv3Parser.ACTION ) {
                          tokens.delete(a.getTokenStartIndex(),
                                        a.getTokenStopIndex());
                          killTrailingNewline(tokens, a.getTokenStopIndex());
                      }
                  }
              }
            });
        wiz.visit(t, ANTLRv3Parser.ARG, // wipe rule arguments
            new TreeWizard.Visitor() {
              public void visit(Object t) {
                  CommonTree a = (CommonTree)t;
                  a = (CommonTree)a.getChild(0);
                  tokens.delete(a.token.getTokenIndex());
                  killTrailingNewline(tokens, a.token.getTokenIndex());
              }
            });
        wiz.visit(t, ANTLRv3Parser.RET, // wipe rule return declarations
            new TreeWizard.Visitor() {
                public void visit(Object t) {
                    CommonTree a = (CommonTree)t;
                    CommonTree ret = (CommonTree)a.getChild(0);
                    tokens.delete(a.token.getTokenIndex(),
                                  ret.token.getTokenIndex());
                }
            });
        wiz.visit(t, ANTLRv3Parser.SEMPRED, // comment out semantic predicates
            new TreeWizard.Visitor() {
                public void visit(Object t) {
                    CommonTree a = (CommonTree)t;
                    tokens.replace(a.token.getTokenIndex(), "/*"+a.getText()+"*/");
                }
            });
        wiz.visit(t, ANTLRv3Parser.GATED_SEMPRED, // comment out semantic predicates
            new TreeWizard.Visitor() {
                public void visit(Object t) {
                    CommonTree a = (CommonTree)t;
                    String text = tokens.toString(a.getTokenStartIndex(),
                                                  a.getTokenStopIndex());
                    tokens.replace(a.getTokenStartIndex(),
                                   a.getTokenStopIndex(),
                                   "/*"+text+"*/");
                }
            });
        wiz.visit(t, ANTLRv3Parser.SCOPE, // comment scope specs
            new TreeWizard.Visitor() {
                public void visit(Object t) {
                    CommonTree a = (CommonTree)t;
                    tokens.delete(a.getTokenStartIndex(),
                                  a.getTokenStopIndex());
                    killTrailingNewline(tokens, a.getTokenStopIndex());
                }
            });        
        wiz.visit(t, ANTLRv3Parser.ARG_ACTION, // args r[x,y] -> ^(r [x,y])
            new TreeWizard.Visitor() {
                public void visit(Object t) {
                    CommonTree a = (CommonTree)t;
                    if ( a.getParent().getType()==ANTLRv3Parser.RULE_REF ) {
                        tokens.delete(a.getTokenStartIndex(),
                                      a.getTokenStopIndex());
                    }
                }
            });
        wiz.visit(t, ANTLRv3Parser.LABEL_ASSIGN, // ^('=' id ^(RULE_REF [arg])), ...
            new TreeWizard.Visitor() {
                public void visit(Object t) {
                    CommonTree a = (CommonTree)t;
                    if ( a.hasAncestor(ANTLRv3Parser.ALT) ) { // avoid options
                        CommonTree child = (CommonTree)a.getChild(0);
                        tokens.delete(a.token.getTokenIndex());     // kill "id="
                        tokens.delete(child.token.getTokenIndex());
                    }
                }
            });
        wiz.visit(t, ANTLRv3Parser.LIST_LABEL_ASSIGN, // ^('+=' id ^(RULE_REF [arg])), ...
            new TreeWizard.Visitor() {
              public void visit(Object t) {
                  CommonTree a = (CommonTree)t;
                  CommonTree child = (CommonTree)a.getChild(0);
                  tokens.delete(a.token.getTokenIndex());     // kill "id+="
                  tokens.delete(child.token.getTokenIndex());
              }
            });


        // AST STUFF
        wiz.visit(t, ANTLRv3Parser.REWRITE,
            new TreeWizard.Visitor() {
              public void visit(Object t) {
                  CommonTree a = (CommonTree)t;
                  CommonTree child = (CommonTree)a.getChild(0);
                  int stop = child.getTokenStopIndex();
                  if ( child.getType()==ANTLRv3Parser.SEMPRED ) {
                      CommonTree rew = (CommonTree)a.getChild(1);
                      stop = rew.getTokenStopIndex();
                  }
                  tokens.delete(a.token.getTokenIndex(), stop);
                  killTrailingNewline(tokens, stop);
              }
            });
        wiz.visit(t, ANTLRv3Parser.ROOT,
           new TreeWizard.Visitor() {
               public void visit(Object t) { AST_SUFFIX(tokens, (CommonTree)t); }
           });
        wiz.visit(t, ANTLRv3Parser.BANG,
           new TreeWizard.Visitor() {
               public void visit(Object t) { AST_SUFFIX(tokens, (CommonTree)t); }
           });
        System.out.print(tokens);
    }

    public static void ACTION(TokenRewriteStream tokens, CommonTree t) {
        CommonTree parent = (CommonTree)t.getParent();
        int ptype = parent.getType();
        if ( ptype==ANTLRv3Parser.SCOPE || // we have special rules for these
             ptype==ANTLRv3Parser.AT )
        {
            return;
        }
        //System.out.println("ACTION: "+t.getText());
        CommonTree root = (CommonTree)t.getAncestor(ANTLRv3Parser.RULE);
        if ( root!=null ) {
            CommonTree rule = (CommonTree)root.getChild(0);
            //System.out.println("rule: "+rule);
            if ( !Character.isUpperCase(rule.getText().charAt(0)) ) {
                tokens.delete(t.getTokenStartIndex(),t.getTokenStopIndex());
                killTrailingNewline(tokens, t.token.getTokenIndex());
            }
        }
    }

    private static void killTrailingNewline(TokenRewriteStream tokens, int index) {
        List all = tokens.getTokens();
        Token after = (Token)all.get(index+1);
        String ws = after.getText();
        if ( ws.startsWith("\n") ) {
            //System.out.println("killing WS after action");
            if ( ws.length()>1 ) {
                tokens.replace(after.getTokenIndex(), ws.substring(1));
            }
            else {
                tokens.delete(after.getTokenIndex());
            }
        }
    }

    public static void AST_SUFFIX(TokenRewriteStream tokens, CommonTree t) {
        tokens.delete(t.token.getTokenIndex());
    }
}
