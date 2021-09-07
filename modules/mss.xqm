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

declare function mss:get-record-uri($rec as node()+) as xs:string? {
  let $recUri := $rec//tei:msDesc/tei:msIdentifier/tei:idno[@type="URI"]/text()
  let $recUri := if (fn:starts-with($recUri, $config:uri-base)) then $recUri else $config:uri-base||$recUri
  return $recUri
};

declare function mss:get-shelf-mark($rec as node()+) as xs:string* {
  let $shelfMark :=  $rec//tei:msDesc/tei:msIdentifier/tei:altIdentifier/tei:idno[@type="BL-Shelfmark"]/text()
  return $shelfMark
};

declare function mss:clean-shelf-mark($shelf-mark as xs:string) as xs:string* {
  let $shelfMarkPreamble := $config:project-config/config/projectMetadata/shelfMarkPrefix/text()
  
  let $shelfMarkNumber := if (fn:contains($shelf-mark, "fo")) then fn:substring-before($shelf-mark, " fo") else $shelf-mark (: ignore any suffix foll. designation :)
  let $shelfMarkNumber := fn:string-join(functx:get-matches($shelfMarkNumber, "\d+"), "")
  
  let $shelfMarkSuffix := if (fn:contains($shelf-mark, "fo")) then "fo"||fn:substring-after($shelf-mark, "fo") else ""
  let $shelfMarkSuffix := if ($shelfMarkSuffix != "") then ", "||$shelfMarkSuffix
  return $shelfMarkPreamble||" "||$shelfMarkNumber||$shelfMarkSuffix
};

declare function mss:create-editor-element($editorUri as xs:string*, $role as xs:string*) as node() {
  let $editorNameString := mss:get-editor-name-from-uri($editorUri)
  let $editorUriBase := $config:editors-document-uri
  let $editorUri := if(not(fn:starts-with($editorUri, $editorUriBase))) then $editorUriBase||"#"||$editorUri else $editorUri
  return element {QName("http://www.tei-c.org/ns/1.0", "editor")}
                                      {attribute {"role"} {$role}, attribute {"ref"} {$editorUri}, $editorNameString}
};

declare function mss:get-editor-name-from-uri($editorUri as xs:string*) as xs:string {
  let $editorNames := for $editor in $config:editors-document//tei:listPerson/tei:person
    where fn:string($editor/@xml:id) = $editorUri
    return $editor/tei:persName/*
  let $editorNameString := fn:string-join($editorNames, " ")
  return $editorNameString
};
(: NOTE lots of redundancy with creating the editor element. maybe have a more generic lookup that gets the URI and text node that these funcs call:)
declare function mss:create-resp-stmt($respNameUri as xs:string*, $respMessage as xs:string*) as node() {
  let $respNameString := mss:get-editor-name-from-uri($respNameUri)
  let $respNameUriBase := $config:editors-document-uri
  let $respNameUri := if(not(fn:starts-with($respNameUri, $respNameUriBase))) then $respNameUriBase||"#"||$respNameUri else $respNameUri
  let $respElement := element {QName("http://www.tei-c.org/ns/1.0", "resp")} {$respMessage}
  let $respNameElement := element {QName("http://www.tei-c.org/ns/1.0", "name")} {attribute {"type"} {"person"}, attribute {"ref"} {$respNameUri}, $respNameString}
  return element {QName("http://www.tei-c.org/ns/1.0", "respStmt")} {$respElement, $respNameElement}
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
  let $fileDesc := mss:update-fileDesc($rec)
  let $encodingDesc := $config:project-config/config/tei:encodingDesc
  let $profileDesc := mss:update-profileDesc($rec)
  let $revisionDesc := mss:update-revisionDesc($rec//tei:revisionDesc)
  return element {QName("http://www.tei-c.org/ns/1.0", "teiHeader")} {$fileDesc, $encodingDesc, $profileDesc, $revisionDesc}
};

(: Build fileDesc :)
declare function mss:update-fileDesc($rec as node()+) as node() {
  let $titleStmt := mss:update-titleStmt($rec)
  let $editionStmt := $config:project-config/config/tei:editionStmt
  let $publicationStmt := mss:update-publicationStmt($rec)
  return element {QName("http://www.tei-c.org/ns/1.0", "fileDesc")} {
    $titleStmt, $editionStmt, $publicationStmt
  }
};

(: Build titleStmt :)

declare function mss:update-titleStmt($rec) as node()* {
  let $recordTitle := mss:create-record-title($rec)
  let $projectMetadata := $config:project-config/config/tei:titleStmt/*[not(self::tei:respStmt)]
  
  let $creatorUri := xs:string($rec//tei:revisionDesc/tei:change[not(@subtype) and contains(text(), "Initial")]/@who) (: gets editor ID of the person who created this TEI record stub :)
  let $creatorUri := functx:substring-after-if-contains($creatorUri, "#") (:only takes ID portion if the full editor URI was used:)
  let $creatorTeiEditorElement := mss:create-editor-element($creatorUri, "creator")
  
  let $creatorRespStmt := mss:create-resp-stmt($creatorUri, "Created by")
  let $projectRespStmts := $config:project-config/config/tei:titleStmt/tei:respStmt
  return element {QName("http://www.tei-c.org/ns/1.0", "titleStmt")} {$recordTitle, $projectMetadata, $creatorTeiEditorElement, $creatorRespStmt, $projectRespStmts}
};

declare function mss:create-record-title($rec as node()+) as node()* {
  let $title := mss:clean-shelf-mark(mss:get-shelf-mark($rec))
  return element {QName("http://www.tei-c.org/ns/1.0", "title")} 
                  {attribute {"xml:lang"} {"en"}, attribute {"level"} {"a"}, $title}
};

(: Note: editionStmt will only have project metadata, so mss:update-fileDesc() simply points to the config:project-config XML file :)

(: Build publicationStmt :)

declare function mss:update-publicationStmt($rec as node()+) as node() {
  let $publicationMetadata := $config:project-config/config/tei:publicationStmt
  let $publicationAuthority := $publicationMetadata/tei:authority
  let $recUri := mss:get-record-uri($rec)
  let $publicationIdno := element {QName("http://www.tei-c.org/ns/1.0", "idno")} {attribute {"type"} {"URI"}, $recUri||"/tei"}
  let $publicationAvailability := $publicationMetadata/tei:availability
  let $publicationDate := element {QName("http://www.tei-c.org/ns/1.0", "date")} {attribute {"calendar"} {"Gregorian"}, fn:current-date()}
  return element {QName("http://www.tei-c.org/ns/1.0", "publicationStmt")} {$publicationAuthority, $publicationIdno, $publicationAvailability, $publicationDate}
};

(: Build Source Desc :)

(: PENDING :)

(: Note: encodingDesc will only have project metadata, so mss:update-teiHeader() simply points to the config:project-config XML file 
: Caveat: would we want to have these functions to access them later in simple update scripts? (E.g., you could make a batch change by a simple 'for $x in $mssColl update encodingDesc with mss:update-encodingDesc()') --> to think on; same for editionStmt
:)

(: Build profileDesc :)

declare function mss:update-profileDesc($rec as node()+) as node() {
  let $langUsage := $config:project-config/config/tei:profileDesc/tei:langUsage
  let $textClass := mss:create-textClass(mss:get-record-uri($rec))
  return element {QName("http://www.tei-c.org/ns/1.0", "profileDesc")} {$langUsage, $textClass}
};

declare function mss:create-textClass($uri as xs:string) as node() {
  let $recId := functx:substring-after-if-contains($uri, "manuscript/")
  let $keywordsSeq := for $keyword in $config:project-config/config/tei:profileDesc/tei:textClass/tei:keywords
      return mss:create-keywords-node($recId, fn:string($keyword/@scheme))
  return element {QName("http://www.tei-c.org/ns/1.0", "textClass")} {$keywordsSeq}
};

declare function mss:create-keywords-node($recId as xs:string, $keywordScheme as xs:string) as node() {
  let $keywordScheme := functx:substring-after-if-contains($keywordScheme, "#")
  let $keywordContent := switch ($keywordScheme)
    case "Wright-BL-Taxonomy" return mss:create-wright-taxonomy-node($recId)
    (: add more cases as needed :)
    default return ()
  return element {QName("http://www.tei-c.org/ns/1.0", "keywords")} {attribute {"scheme"} {"#"||$keywordScheme}, $keywordContent}
};

declare function mss:create-wright-taxonomy-node($recId as xs:string) as node() {
  let $wrightTaxonomyValue := decoder:get-wright-taxonomy-id-from-uri($recId)
  let $wrightTaxonomyRefNode := element {QName("http://www.tei-c.org/ns/1.0", "ref")} {attribute {"target"} {"#"||$wrightTaxonomyValue}}
  let $wrightTaxonomyItemNode := element {QName("http://www.tei-c.org/ns/1.0", "item")} {$wrightTaxonomyRefNode}
  let $wrightTaxonomyListNode := element {QName("http://www.tei-c.org/ns/1.0", "list")} {$wrightTaxonomyItemNode}
  return $wrightTaxonomyListNode
};
(: Build revisionDesc :)

declare function mss:update-revisionDesc($revisionDesc as node()+) as node() {
  let $currentDate := fn:current-date()
  let $currentDate := fn:substring(xs:string($currentDate), 1, 10)
  let $newChangeLogElement := element {QName("http://www.tei-c.org/ns/1.0", "change")} {attribute {"who"} {$config:editors-document-uri||"#"||$config:change-log-script-id}, attribute {"when"} {$currentDate}, $config:change-log-message}
   return element {QName("http://www.tei-c.org/ns/1.0", "revisionDesc")} {$revisionDesc/@*, $newChangeLogElement, $revisionDesc/*}
};

(: Build tei:fascimile and tei:text :)

(: LIST OF NEEDED FUNCTIONS

## general utility

- delete-enumerations
- renumber-simple-list (for handNotes and additions/items, though could work for msItems for the n values?)

## updating tei sections and subsections


- update-fileDesc
- update-titleStmt

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
            
- update-physDesc
- update-condition
- update-handDesc
- renumber-handNotes
- update-additions
- renumber-additions-items
- update-history
- update-wright-bibl-entry
:)