xquery version "3.0";

(:
: Module Name: Syriaca.org Manuscript Cataloguing
: Module Version: 0.1
: Copyright: GNU General Public License v3.0
: Proprietary XQuery Extensions Used: None
: XQuery Specification: 08 April 2014
: Module Overview: This module contains functions and variable declarations
:                  used in the data pipeline for the Syriaca.org manuscript
:                  encoding project.
:)

(:
ADD XQDOC COMMENTS HERE (SEE STYLE GUIDE P 14)
:)

module namespace mss="http://srophe.org/srophe/mss";

import module namespace functx="http://www.functx.com";
import module namespace config="http://srophe.org/srophe/config" at "config.xqm";
import module namespace decoder="http://srophe.org/srophe/decoder" at "decoder.xqm";

declare namespace tei = "http://www.tei-c.org/ns/1.0";

(: LIST OF NEEDED FUNCTIONS
- functions for adding static metatdata
- get-record-uri
- get-record-shelfMark
- get-record-
- clean-shelfmark
- update-titleStmt
- update-record-title
- create-editor-list
- create-respStmt-list
- update-publicationStmt
- update-msDesc
- update-msIdentifier
- update-msContents
  - a bunch of helper functions for this one...
  - delete-msItem-enumeration
  - renumber-msItems
- processing instructions
- update-physDesc
- update-condition
- update-handDesc
- renumber-handNotes
- update-additions
- renumber-additions-items
- update-history
- update-wright-bibl-entry
- encodingDesc is all static
- profileDesc
  - langUsage is static
  - update-textClass (uses taxonomy)
- update-revisionDesc
:)
(:
I think here's how we proceed:

3. write the main variable declarations and config file
4. go through the other functions, move them here, refactor, simplify, and generalize as needed
5. keep checking that you haven't broken anything
:)