xquery version "3.0";

(:
: Module Name: Syriaca.org Manuscript Parts Merging
: Module Version: 1.0
: Copyright: GNU General Public License v3.0
: Proprietary XQuery Extensions Used: None
: XQuery Specification: 08 April 2014
: Module Overview: This module contains functions and variable declarations
:                  used to merge TEI XML files describing manuscript parts
:                  into a single TEI XML file with nested tei:msPart elements
:)

(:
ADD XQDOC COMMENTS HERE (SEE STYLE GUIDE P 14)
:)
module namespace msParts="http://srophe.org/srophe/msParts";

import module namespace functx="http://www.functx.com";
import module namespace config="http://srophe.org/srophe/config" at "config.xqm";
import module namespace mss="http://srophe.org/srophe/mss" at "mss.xqm";

declare namespace tei = "http://www.tei-c.org/ns/1.0";


declare variable $msParts:config-msParts :=
  let $pathToConfig := $config:path-to-repo || "/parameters/config-msParts.xml"
  return fn:doc($pathToConfig);



(:
To-do
- functions needed
  - combine editor[@role="creator"] element list (distinct-nodes)
  - combine respStmt elements whose resp/text() is either "Created by" or "Edited by" (distinct-nodes) or "Project management by"
  - merge these into an updated titleStmt
    - a-level title is gotten from the shel-mark in the msParts-config
    - everything is static but the creator editors (dmichelson and raydin should be 1 and 2, then the unique list)
    - respStmts should go Created by; Wright; Edited by; Syriac; Greek and coptic; Proj mgmt; English
  - new pubStmt using overall URI (and update pub date)
- msDesc is combined as follows
  - xml:id based on overall id
  - msIdentifier for overall has country, settlement, repository, collection from ms config; URI for overall and BL-Shelfmark for overall. But no Wright #s
  - each file gives an msPart that has xml:id of Part\d+, etc.
    - msIdentifier as-is from the file
    - msContents as is but with updated xml:ids with p\d+ prepended based on position in sequence. (note that this will require creating a table to update linked data)
    - physDesc > objectDesc as-is
    - physDesc > handDesc with updated handNotes prepending the p\d+ string to the xml:ids
      - same idea for additions and for decoDesc if needed
    - history as-is
    - additional
      - update the adminInfo//source/ref/@target to "#WrightPart\d+" based on position in sequence
        - this is the updated xml:id on the additional/listBibl/bibl that was "Wright"
 - textClass/keywords[@scheme="#Wright-Bl-Taxonomy"]/list needs items for each file with the ref as-is but with an additional ref with target to the associated msPart. 
 - revisionDesc should come through with the associated msPart URI added (like the merge places and persons scripts do for duplicate URIs) to indicate which URIs each tei:change is associated with (including planned changes as this is important for later stages). Also add a tei:change for the merge itself. 

:)