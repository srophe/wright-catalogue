xquery version "3.0";

(:
: Module Name: Unit Testing for Syriaca.org Manuscript Cataloguing
: Module Version: 0.1
: Copyright: GNU General Public License v3.0
: Proprietary XQuery Extensions Used: None
: XQuery Specification: 08 April 2014
: Module Overview: This module contains unit tests for developing the
                   Syriaca.org manuscript module.
:)

module namespace mss-test="http://srophe.org/srophe/mss/mss-test";

import module namespace mss="http://srophe.org/srophe/mss" at "mss.xqm";
import module namespace config="http://srophe.org/srophe/config" at "config.xqm";

declare namespace tei = "http://www.tei-c.org/ns/1.0";

declare variable $mss-test:file-to-test := 
  let $path-to-file := $config:path-to-repo||"/resources/testing/317_testable.xml"
  return fn:doc($path-to-file);
  
declare variable $mss-test:file-to-compare :=
  let $path-to-file := $config:path-to-repo||"/resources/testing/317_full.xml"
  return fn:doc($path-to-file);

declare %unit:before function mss-test:setup() {
  
};

declare %unit:after function mss-test:teardown() {
  
};

declare %unit:test function mss-test:create-processing-instructions-from-config() {
  unit:assert-equals(mss:create-processing-instructions(), $mss-test:file-to-compare/processing-instruction())
};

declare %unit:test function mss-test:create-document-with-processing-instructions() {
  unit:assert-equals(mss:create-document($mss-test:file-to-compare/*), $mss-test:file-to-compare)
};

declare %unit:test %unit:ignore function mss-test:create-teiHeader() {
  unit:assert-equals(mss:update-teiHeader($mss-test:file-to-compare/*), $mss-test:file-to-compare/teiHeader)
};
(: test whether the teiHeader of the processed file is the same as the hand-done file; should fail for a while 
SKIPPING UNTIL READY TO TEST
:)

declare %unit:test function mss-test:create-record-title() {
   unit:assert-equals(mss:create-record-title($mss-test:file-to-test), $mss-test:file-to-compare//tei:titleStmt/tei:title[@level="a"])
};

declare %unit:test function mss-test:clean-shelf-mark-preamble-no-follia-range() {
  unit:assert-equals(mss:clean-shelf-mark("Add. 14,581"), "BL Add MS 14581")
};

declare %unit:test function mss-test:clean-shelf-mark-preamble-follia-range() {
  unit:assert-equals(mss:clean-shelf-mark("Add. 14,581, foll. 1-31"), "BL Add MS 14581, foll. 1-31")
};

declare %unit:test function mss-test:get-editor-name-from-uri-first-last-name() {
  unit:assert-equals(mss:get-editor-name-from-uri("lruth"), "Lindsay Ruth")
};

declare %unit:test function mss-test:get-editor-name-from-uri-first-middle-last-name() {
  unit:assert-equals(mss:get-editor-name-from-uri("wpotter"), "William L. Potter")
};

declare %unit:test function mss-test:get-editor-name-from-uri-title-first-last-name() {
  unit:assert-equals(mss:get-editor-name-from-uri("rakhrass"), "Dayroyo Roger-Youssef Akhrass")
};

(:
: List of tests
: - reading inputs
: - writing outputs
: - wright-decoder creation
: - taxonomy creation
: - titleStmt
: 	- editors and respStmts
: - pubStmt (URI)
: - msDesc (xml:id)
: 	- msIdentifier
: 	- msParts (later)
: 	- msContents
: 		- msItem and sub-items?? (or is this contained in msContents, as long as the right numbering is applied? I suppose if we include remove items testing this might be useful)
: - physDesc
: 	- condition description
: 	- handDesc
: 	- decoDesc
: 	- additions
: - handling empty versions of certain things like decoDesc, etc.
: - origDate and origPlace
: - citedRange in //additional/listBibl/bibl
: - textClass
: - msPart will have additional testing most likely, but for now just refactor based on the above tests
:)