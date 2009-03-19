package org.antlr.gunit.swingui.model;

import java.io.*;
import java.util.*;
import java.util.logging.Level;
import java.util.logging.Logger;
import org.antlr.gunit.swingui.parsers.*;
import org.antlr.runtime.*;
import org.antlr.stringtemplate.*;

public class TestSuiteFactory {
    
    private static String TEMPLATE_FILE = "gunit.stg";
    private static StringTemplateGroup templates;
    public static final String TEST_SUITE_EXT = ".gunit";
    public static final String GRAMMAR_EXT = ".g";
    
    static  {
        InputStream in = TestSuiteFactory.class.getResourceAsStream(TEMPLATE_FILE);
        Reader rd = new InputStreamReader(in);
        templates = new StringTemplateGroup(rd);
    }
    
    /**
     * Factory method: create a testsuite from ANTLR grammar.  Save the test 
     * suite file in the same directory of the grammar file.
     * @param grammarFile ANTLRv3 grammar file.
     * @return test suite object
     */
    public static TestSuite createTestSuite(File grammarFile) {
        if(grammarFile != null && grammarFile.exists() && grammarFile.isFile()) {
            
            final String fileName = grammarFile.getName();
            final String grammarName = fileName.substring(0, fileName.lastIndexOf('.'));
            final String grammarDir = grammarFile.getParent();
            final File testFile = new File(grammarDir + File.separator + grammarName + TEST_SUITE_EXT);
            
            final TestSuite result = new TestSuite(grammarName, testFile);
            result.rules = loadRulesFromGrammar(grammarFile);
            
            if(saveTestSuite(result)) {
                return result;
            } else {
                throw new RuntimeException("Can't save test suite file.");
            }
        } else {
            throw new RuntimeException("Invalid grammar file.");
        }
    }

    
    /* Load rules from an ANTLR grammar file. */
    private static List<Rule> loadRulesFromGrammar(File grammarFile) {
        
        // get all the rule names
        final List<String> ruleNames = new ArrayList<String>();
        try {
            final Reader reader = new BufferedReader(new FileReader(grammarFile));
            final ANTLRv3Lexer lexer = new ANTLRv3Lexer(new ANTLRReaderStream(reader));
            final CommonTokenStream tokens = new CommonTokenStream(lexer);
            final ANTLRv3Parser parser = new ANTLRv3Parser(tokens);
            parser.rules = ruleNames;
            parser.grammarDef();
            reader.close();
        } catch (Exception e) {
            e.printStackTrace();
        }

        // convert to rule object
        final List<Rule> ruleList = new ArrayList<Rule>();
        for(String str: ruleNames) {
            ruleList.add(new Rule(str));
        }

        return ruleList;
    }    

    /* Save testsuite to *.gunit file. */
    public static boolean saveTestSuite(TestSuite testSuite) {
        final String data = getScript(testSuite);
        try {
            FileWriter fw = new FileWriter(testSuite.getTestSuiteFile());
            fw.write(data);
            fw.flush();
            fw.close();    
        } catch (IOException e) {
            e.printStackTrace();
            return false;
        }
        return true;
    }
    
    /**
     * Get the text script from the testSuite.
     * @param testSuite
     * @return test script
     */
    public static String getScript(TestSuite testSuite) {
        if(testSuite == null) return null;
        StringTemplate gUnitScript = templates.getInstanceOf("gUnitFile");
        gUnitScript.setAttribute("testSuite", testSuite);
        
        return gUnitScript.toString();        
    }
    
    /**
     * From textual script to program model.
     * @param file testsuite file (.gunit)
     * @return test suite object
     */
    public static TestSuite loadTestSuite(File file) {
        // check grammar file
        final File grammarFile = getGrammarFile(file);
        if(grammarFile == null) 
            throw new RuntimeException("Can't find grammar file.");
            
        TestSuite result = new TestSuite("", file);
        
        // read in test suite
        try {
            final Reader reader = new BufferedReader(new FileReader(file));
            final StGUnitLexer lexer = new StGUnitLexer(new ANTLRReaderStream(reader));
            final CommonTokenStream tokens = new CommonTokenStream(lexer);
            final StGUnitParser parser = new StGUnitParser(tokens);
            final TestSuiteAdapter adapter = new TestSuiteAdapter(result);
            parser.adapter = adapter;
            parser.gUnitDef();
            result.setTokens(tokens);
            reader.close();            
        } catch (Exception ex) {
            throw new RuntimeException("Error reading test suite file.\n" + ex.getMessage());
        }
        
        // load un-tested rules from grammar
        final List<Rule> completeRuleList = loadRulesFromGrammar(grammarFile);
        for(Rule rule: completeRuleList) {
            if(!result.hasRule(rule)) {
                result.addRule(rule);
                //System.out.println("Add rule:" + rule);
            }
        }

        return result;
    }
    
    /**
     * Get the grammar file of the testsuite file in the same directory.
     * @param testsuiteFile
     * @return grammar file or null
     */
    private static File getGrammarFile(File testsuiteFile) {
        final String sTestFile;
        try {
            sTestFile = testsuiteFile.getCanonicalPath();
        } catch (IOException e) {
            return null;
        }
        final String sGrammarFile = sTestFile.substring(0, sTestFile.lastIndexOf('.')) + GRAMMAR_EXT;
        final File fileGrammar = new File(sGrammarFile); 
        if(fileGrammar.exists() && fileGrammar.isFile())
            return fileGrammar;
        else
            return null;
    }
}