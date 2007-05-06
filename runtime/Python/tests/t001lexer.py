import antlr3
import testbase
import unittest

class t001lexer(testbase.ANTLRTest):
    def setUp(self):
        self.compileGrammar()
        
        
    def testValid(self):
        stream = antlr3.StringStream('0')
        lexer = self.getLexer(stream)

        token = lexer.nextToken()
        self.failUnlessEqual(token.type, self.lexerModule.ZERO)

        token = lexer.nextToken()
        self.failUnlessEqual(token.type, self.lexerModule.EOF)
        

    def testMalformedInput(self):
        stream = antlr3.StringStream('1')
        lexer = self.getLexer(stream)

        try:
            token = lexer.nextToken()
            self.fail()

        except antlr3.MismatchedTokenException, exc:
            self.failUnlessEqual(exc.expecting, '0')
            self.failUnlessEqual(exc.unexpectedType, '1')
            

if __name__ == '__main__':
    unittest.main()
