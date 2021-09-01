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

(: General helper functions :)

declare function mss:clean-shelf-mark($shelf-mark as xs:string) as xs:string* {
  let $shelfMarkPreamble := $config:project-config/config/projectMetadata/shelfMarkPrefix/text()
  
  let $shelfMarkNumber := if (fn:contains($shelf-mark, "fo")) then fn:substring-before($shelf-mark, " fo") else $shelf-mark (: ignore any suffix foll. designation :)
  let $shelfMarkNumber := fn:string-join(functx:get-matches($shelfMarkNumber, "\d+"), "")
  
  let $shelfMarkSuffix := if (fn:contains($shelf-mark, "fo")) then "fo"||fn:substring-after($shelf-mark, "fo") else ""
  let $shelfMarkSuffix := if ($shelfMarkSuffix != "") then ", "||$shelfMarkSuffix
  return $shelfMarkPreamble||" "||$shelfMarkNumber||$shelfMarkSuffix
};

(: Functions to turn XML Stub records into full TEI files :)

declare function mss:create-document($rec as node()+) as document-node() {
  let $processing-instructions := mss:create-processing-instructions()
  return document {$processing-instructions, $rec}
};

declare function mss:create-processing-instructions() as processing-instruction()* {
  let $processingInstructionsConfig := $config:project-config/config/processingInstructions
  for $pi in $processingInstructionsConfig/processingInstruction
    let $piName := $pi/name
    let $piParameters := for $param in $pi/parameter
      (: returns a sequence of strings of form "nameString="valueString"":)
      return $param/name/text()||"=&quot;"||$param/value/text()||"&quot;"
    return processing-instruction {$piName} {$piParameters}
};

(: Build document from component parts :)

(: Build teiHeader :)
declare function mss:update-teiHeader($rec as node()+) as node() {
  let $fileDesc := mss:update-fileDesc($rec//fileDesc)
  let $encodingDesc := mss:update-encodingDesc($rec//encodingDesc)
  let $profileDesc := mss:update-profileDesc($rec//profileDesc)
  let $revisionDesc := mss:update-revisionDesc($rec//revisionDesc)
  return element {QName("http://www.tei-c.org/ns/1.0", "teiHeader")} {$fileDesc, $encodingDesc, $profileDesc, $revisionDesc}
};

(: Build fileDesc :)
declare function mss:update-fileDesc($fileDesc as node()+) as node() {
  let $titleStmt := mss:update-titleStmt()
  let $editionStmt := mss:update-editionStmt($fileDesc/editionStmt)
  let $publicationStmt := mss:update-publicationStmt($fileDesc/publicationStmt)
  return element {QName("http://www.tei-c.org/ns/1.0", "fileDesc")} {
    $titleStmt, $editionStmt, $publicationStmt
  }
};

(: Build titleStmt :)

declare function mss:update-titleStmt() as node()* {
  let $recordTitle := mss:create-record-title()
  return $recordTitle
};

declare function mss:create-record-title() as node()* {
  
};

(: Build editionStmt :)

declare function mss:update-editionStmt($editionStmt as node()+) as node() {
  
};

(: Build publicationStmt :)

declare function mss:update-publicationStmt($publicationStmt as node()+) as node() {
  
};

(: Build encodingDesc :)

declare function mss:update-encodingDesc($encodingDesc as node()+) as node() {
  
};

(: Build profileDesc :)

declare function mss:update-profileDesc($profileDesc as node()+) as node() {
  
};

(: Build revisionDesc :)

declare function mss:update-revisionDesc($revisionDesc as node()+) as node() {
  
};

(: Build tei:fascimile and tei:text :)

(: LIST OF NEEDED FUNCTIONS

## general utility

- get-record-uri
- delete-enumerations
- renumber-simple-list (for handNotes and additions/items, though could work for msItems for the n values?)

## updating tei sections and subsections


- update-fileDesc
- update-titleStmt
  - update-record-title
    - get-record-clean-shelf-mark
      - get-record-shelf-mark
      - clean-shelf-mark
  - create-editors-list
  - create-respStmt-list
- update-editionStmt
- update-publicationStmt
  - get-record-uri (see above)
  - current-date
- update-sourceDesc
  - update-msDesc
    - update-msIdentifier
      - get-record-country, settlement, repository, collection (from config)
      - get-record-uri
      - get-record-clean-shelf-mark
      - create-alt-identifier-list
        - get-record-catalogue-reference-prose
        - get-record-wright-arabic-numeral
        - get-record-wright-roman-numeral
   - update-msContents
     - update-msItem-enumeration
     - delete-msItem-enumeration
     - renumber-msItems (huge amount of helper functions)
    - update-physDesc
      - objectDesc stays as is
      - update-handDesc
        - update-handNote-enumeration
          - delete-handNote-enumeration
          - renumber-handNotes
       - update-number-of-hands
      - update-additions (same process as for handNotes but change the prefix, so make this more generic)
        - update-additions-item-enumeration
          - delete-additions-item-enumeration
          - renumber-additions-items
      - decoDesc!!
      - binding and seal descs are pending; accMat/ are unchanged
     - update-history??
  - update-additional
    - update-wright-bibl-entry
      - get-record-wright-roman-numeral
      - get-record-wright-catalog-volume-page
        - get-record-wright-catalog-volume
        - get-record-wright-catalog-page
- update-encoding-desc
  - add-editorial-decl from config file
  - add classDecl from config file
- update-profile-desc
  - add -langUsage from file
  - update-textClass
    - get-record-taxonomy-keyword
- update-revisionDesc
  - update-change-list
    - get-script-editor-id
    - get-change-log-message
    - current-date
            
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