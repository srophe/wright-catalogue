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

declare variable $mss-test:file-to-test := 
  let $path-to-file := $config:path-to-repo||"/resources/testing/317_testable.xml"
  return fn:doc($path-to-file);

declare %unit:before function mss-test:setup() {
  
};

declare %unit:after function mss-test:teardown() {
  
};



(:
: List of tests
: - reading inputs
: - writing outputs
: - processing instructions
: - wright-decoder creation
: - taxonomy creation
: - titleStmt
: 	- title (level a)
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