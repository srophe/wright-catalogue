xquery version "3.0";

(:
: Module Name: Syriaca.org Manuscript Cataloguing
: Module Version: 1.0
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
import module namespace stack="http://wlpotter.github.io/ns/stack" at "https://raw.githubusercontent.com/wlpotter/xquery-utility-modules/main/stack.xqm";

declare namespace tei = "http://www.tei-c.org/ns/1.0";

(: global variables :)
declare variable $mss:initial-msItem-up-stack := 
  stack:initialize(());
  
declare variable $mss:initial-msItem-down-stack :=
  stack:initialize(("a1", "b1", "c1", "d1", "e1", "f1", "g1", "h1", "i1", "j1", "k1", "l1", "m1", "n1"));

(: General helper functions :)

declare function mss:get-record-uri($rec as node()+) as xs:string? {
  let $recUri := $rec//tei:msDesc/tei:msIdentifier/tei:idno[@type="URI"]/text()
  let $recUri := if (fn:starts-with($recUri, $config:uri-base)) then $recUri else $config:uri-base||$recUri
  return $recUri
};

declare function mss:get-shelf-mark($rec as node()+) as xs:string* {
  let $shelfMarkType := $config:project-config/config/projectMetadata/shelfMarkType/text()
  let $shelfMark := $rec//tei:sourceDesc/tei:msDesc/tei:msIdentifier/tei:altIdentifier/tei:idno[@type=$shelfMarkType]/text()
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

declare function mss:enumerate-element-sequence($elementSequence as node()+, $elementIdPrefix as xs:string, $includeAttributeN as xs:boolean) {
  (: adds a numeral attribute value according to sequence position in $elementSequence. If $elementIdPrefix is non-empty, adds an xml:id with the prefix appended to the sequence value. If $includeAttributeN is true, adds an @n attribute with the numerical sequence position. If neither of the above conditions are true, simply returns the element.:)
  for $el at $n in $elementSequence
    let $elementId := if($elementIdPrefix != "") then attribute {"xml:id"} {$elementIdPrefix||$n}
    let $attrN := if($includeAttributeN) then attribute {"n"} {$n}
    return element {node-name($el)} {$elementId, $attrN, $el/@*, $el/*}
}; (:NOTE: For msItems, add an off-set value to this which defaults to 0 but can be used when doing dfs traversal of msContents :)

(: Functions to turn XML Stub records into full TEI files :)

declare function mss:create-updated-document($rec as node()+) as document-node() {
  let $processing-instructions := mss:create-processing-instructions()
  let $rec := $rec/descendant-or-self::*[not(self::processing-instruction())]
  let $rec := mss:update-full-record($rec)
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

declare function mss:update-full-record($rec as node()+) as node() {
  let $teiHeader := mss:update-teiHeader($rec)
  (: let $teiText := mss:update-tei-text-elements($rec)/* :)
  return element {QName("http://www.tei-c.org/ns/1.0", "TEI")} {attribute {"xml:lang"} {"en"}, $teiHeader, $rec/tei:facsimile, $rec/tei:text}
};
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
  let $sourceDesc := mss:update-sourceDesc($rec)
  return element {QName("http://www.tei-c.org/ns/1.0", "fileDesc")} {
    $titleStmt, $editionStmt, $publicationStmt, $sourceDesc
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
                  {attribute {"level"} {"a"}, attribute {"xml:lang"} {"en"}, $title}
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

declare function mss:update-sourceDesc($rec as node()+) as node() {
  let $msDesc := mss:update-msDesc($rec)
  return element {QName("http://www.tei-c.org/ns/1.0", "sourceDesc")} {$msDesc}
};

declare function mss:update-msDesc($rec as node()+) as node() {
  let $msId := functx:substring-after-if-contains(mss:get-record-uri($rec), $config:project-config//projectMetadata/uriBase/text())
  let $msIdentifier := mss:update-msIdentifier($rec)
  let $msContents := mss:update-msContents($rec//tei:msDesc/tei:msContents)
  let $physDesc := mss:update-physDesc($rec//tei:msDesc/tei:physDesc)
  let $history := $rec//tei:msDesc/tei:history
  let $additional := mss:update-ms-additional($msId)
  return element {QName("http://www.tei-c.org/ns/1.0", "msDesc")} {attribute {"xml:id"} {"manuscript-"||$msId}, $msIdentifier, $msContents, $physDesc, $history, $additional}
  
};

declare function mss:update-msIdentifier($rec as node()+) as node() {
  let $msCollectionMetadata := $config:project-config/config//tei:msIdentifier/*[not(self::tei:altIdentifier)] (: get all the static metdata; the altId info will be generated by script :)
  let $uri := mss:get-record-uri($rec)
  let $msIdno := element {QName("http://www.tei-c.org/ns/1.0", "idno")} {attribute {"type"} {"URI"}, $uri}
  let $altIdentifierElements := mss:create-altIdentifier-elements($config:project-config/config//tei:msIdentifier/tei:altIdentifier, $uri)
  
  return element {QName("http://www.tei-c.org/ns/1.0", "msIdentifier")} {$msCollectionMetadata, $msIdno, $altIdentifierElements}
};

declare function mss:create-altIdentifier-elements($altIdentifierSequence as node()*, $recId as xs:string) as node()* {
  let $updatedAltIdentifierSequence := for $altId in $altIdentifierSequence
    let $altIdType := xs:string($altId/tei:idno/@type)
    let $altIdContents := switch($altIdType)
      case "BL-Shelfmark" return mss:create-bl-shelfmark-element($recId)
      case "Wright-BL-Arabic" return mss:create-wright-bl-arabic-element($recId)
      case "Wright-BL-Roman" return mss:create-wright-bl-roman-element($recId)
    default return ()
    return element {QName("http://www.tei-c.org/ns/1.0", "altIdentifier")} {$altIdContents}
  return $updatedAltIdentifierSequence
};

(: a bit of redundancy with the below two functions too...:)
declare function mss:create-bl-shelfmark-element($recId as xs:string) as node() {
  let $recId := functx:substring-after-if-contains($recId, $config:uri-base)
  let $shelfmark := decoder:get-decoder-data-from-uri($recId, "shelfmark")
  let $shelfmark := mss:clean-shelf-mark($shelfmark)
  let $shelfmark := fn:substring-after($shelfmark, "BL ")
  let $idnoElement := element {QName("http://www.tei-c.org/ns/1.0", "idno")} {attribute {"type"} {"BL-Shelfmark"}, $shelfmark}
  return $idnoElement
};

(: lots of redundancy in arabic and roman numeral element creation. figure out refactoring :)
declare function mss:create-wright-bl-arabic-element($recId as xs:string) as node()+ {
  let $recId := functx:substring-after-if-contains($recId, $config:uri-base)
  let $wrightArabicNumeral := decoder:get-decoder-data-from-uri($recId, "wrightArabicNumeral")
  let $collectionElement := element {QName("http://www.tei-c.org/ns/1.0", "collection")} {"William Wright, Catalogue of the Syriac Manuscripts in the British Museum Acquired since the Year 1838"(:this should come from somewhere:)}
  let $idnoElement := element {QName("http://www.tei-c.org/ns/1.0", "idno")} {attribute {"type"} {"Wright-BL-Arabic"}, $wrightArabicNumeral}
  return ($collectionElement, $idnoElement)
};

declare function mss:create-wright-bl-roman-element($recId as xs:string) as node()+ {
  let $recId := functx:substring-after-if-contains($recId, $config:uri-base)
  let $wrightRomanNumeral := decoder:get-decoder-data-from-uri($recId, "wrightRomanNumeral")
  let $collectionElement := element {QName("http://www.tei-c.org/ns/1.0", "collection")} {"William Wright, Catalogue of the Syriac Manuscripts in the British Museum Acquired since the Year 1838"(:this should come from somewhere:)}
  let $idnoElement := element {QName("http://www.tei-c.org/ns/1.0", "idno")} {attribute {"type"} {"Wright-BL-Roman"}, $wrightRomanNumeral}
  return ($collectionElement, $idnoElement)
};

declare function mss:update-msContents($msContents as node()+) as node() { (: PENDING. This one will be difficult as it requires enumerating the msItems... :)
  let $summary := $msContents/tei:summary
  let $textLang := if($msContents/tei:textLang) then $msContents/tei:textLang
                       else element {QName("http://www.tei-c.org/ns/1.0", "textLang")} {attribute {"mainLang"} {$config:project-config/config/projectMetadata/msMainLang/text()}}
  let $msItems := mss:add-msItem-id-and-enumeration-values(<msItemContainer>{$msContents/tei:msItem}</msItemContainer>, $mss:initial-msItem-up-stack, $mss:initial-msItem-down-stack, 1)[1]/tei:msItem
  return element {QName("http://www.tei-c.org/ns/1.0", "msContents")} {$summary, $textLang, $msItems}
};

(: this is the recursive function that adds @xml:id and @n values to msItems. It is in much better shape than the previous attempt and makes use of vertical and horizontal recursion. It keeps track of values using two XQuery stacks, which I've implemented in the stack module (see import above). 

This function is much clearer than previous but could likely still use some refactoring. Tests are set up in tests.mss.xqm, so any refactoring should keep these green to ensure proper script performance.
:)
declare function mss:add-msItem-id-and-enumeration-values($msItemSeq as node(), $up-stack as node(), $down-stack as node(), $currentItemNumber as xs:integer) {
  (: currently processing first node in the sequence :)
  let $currentNode := $msItemSeq/tei:msItem[1]
  let $currentNodeNum := attribute {"n"} {$currentItemNumber}
  (: pop the $down-stack and store in $id. Note that XQuery's limitations require popping a stack to be a two-step process (see stack.xqm for more) :)
  let $id := stack:pop($down-stack)[1]
  let $down-stack :=stack:pop($down-stack)[2]
  
  (: stor popped id as the id for the current node context :)
  let $currentNodeId := $id
  
  (: iterate the numerical portion of the $id and push onto the $up-stack :)
  
  let $id := substring($id, 1, 1)||(xs:integer(fn:substring($id, 2, fn:string-length($id)))+1)
  let $up-stack := stack:push($up-stack, $id)
  
  (: process child-data recursively using the current stack states :)
  let $child-seq := <msItemContainer>{$currentNode/tei:msItem}</msItemContainer>
  let $child-data := if ($child-seq/tei:msItem) then mss:add-msItem-id-and-enumeration-values($child-seq, $up-stack, $down-stack, $currentItemNumber + 1) else ()
  
  (: $child-data now contains the processed-child nodes of $currentNode as well as the updated stack states as a three-item list.
  : Store the child nodes as $child-seq and update the stack states from $child-data
   :)
  let $child-seq := if(not(empty($child-data))) then $child-data[1] else $child-seq
  let $up-stack := if(not(empty($child-data))) then $child-data[2] else $up-stack
  let $down-stack := if(not(empty($child-data))) then $child-data [3] else $down-stack
  let $currentItemNumber := if(not(empty($child-data))) then $child-data [4] else $currentItemNumber
  
  (: pop the up-stack and push its value onto the down-stack. This ensures that the sibling nodes are processed at the same level in the stack :)
  let $down-stack := stack:push($down-stack, stack:pop($up-stack)[1])
  let $up-stack := stack:pop($up-stack)[2]
  
  (: store any sibling msItems as a sequence and process using the current stack states:)
  let $sibling-seq := <msItemContainer>{$msItemSeq/tei:msItem[position()>1]}</msItemContainer>
  let $sibling-data := if ($sibling-seq/tei:msItem) then mss:add-msItem-id-and-enumeration-values($sibling-seq, $up-stack, $down-stack, $currentItemNumber+1) else ()
  
  (: as with child processing, update the sibling-seq, up-stack, and down-stack states with the returns :)
  let $sibling-seq := if(not(empty($sibling-data))) then $sibling-data[1] else $sibling-seq
  let $up-stack := if(not(empty($sibling-data))) then $sibling-data[2] else $up-stack
  let $down-stack := if(not(empty($sibling-data))) then $sibling-data[3] else $down-stack
  let $currentItemNumber := if(not(empty($sibling-data))) then $sibling-data [4] else $currentItemNumber
  
  let $elementReturnSeq := (element {node-name($currentNode)} {attribute {"xml:id"} {$currentNodeId}, $currentNodeNum, $currentNode/@*, $currentNode/*[not(name()='msItem')], $child-seq/tei:msItem}, $sibling-seq/tei:msItem)
  return (<msItemContainer>{$elementReturnSeq}</msItemContainer>, $up-stack, $down-stack, $currentItemNumber)
};

declare function mss:update-physDesc($physDesc as node()+) as node()+ {
  let $objectDesc := $physDesc/tei:objectDesc
  let $handDesc := mss:update-handDesc($physDesc/tei:handDesc)
  let $decoDesc := if($physDesc/tei:decoDesc) then mss:update-decoDesc($physDesc/tei:decoDesc)
  let $additions := if($physDesc/tei:additions/tei:list/tei:item) then mss:update-additions($physDesc/tei:additions) else element {QName("http://www.tei-c.org/ns/1.0", "additions")} {}
  let $bindingDesc := $physDesc/tei:bindingDesc (: as-is :)
  let $sealDesc := $physDesc/tei:sealDesc (: as-is :)
  let $accMat := $physDesc/tei:accMat (: as-is :)
  
  return element {QName("http://www.tei-c.org/ns/1.0", "physDesc")} {$objectDesc, $handDesc, $decoDesc, $additions, $bindingDesc, $sealDesc, $accMat}
};

declare function mss:update-handDesc($handDesc as node()+) as node() {
  let $numberOfHands := fn:count($handDesc/tei:handNote)
  let $handNoteSeq := mss:update-handNote-sequence($handDesc/tei:handNote)
  return element {QName("http://www.tei-c.org/ns/1.0", "handDesc")} {attribute {"hands"} {$numberOfHands}, $handNoteSeq}
};

declare function mss:update-handNote-sequence($handNoteSequence as node()+) as node()+ {
  let $handNoteSequence := mss:enumerate-element-sequence($handNoteSequence, "handNote", fn:boolean(0))
  let $numberOfHands := fn:count($handNoteSequence)
  let $handNoteSequence := for $handNote in $handNoteSequence
    let $medium := if (fn:string($handNote/@medium) != "") then $handNote/@medium else attribute {"medium"} {"unknown"}
    let $scope := if (fn:string($handNote/@scope) != "") then $handNote/@scope
      else if (xs:integer($numberOfHands) < 2) then attribute {"scope"} {"sole"} 
      else if (fn:string($handNote/@xml:id) = "handNote1") then attribute {"scope"} {"major"} 
      else attribute {"scope"} {"minor"} 
    let $script := if (fn:string($handNote/@script) != "") then $handNote/@script else attribute {"script"} {"syr"}
    return element {QName("http://www.tei-c.org/ns/1.0", "handNote")} {$handNote/@xml:id, $medium, $scope, $script, $handNote/*}
 return $handNoteSequence
};

declare function mss:update-decoDesc($decoDesc as node()+) as node() { (:not currently tested:)
  let $decoNotes := mss:enumerate-element-sequence($decoDesc/tei:decoNote, "decoNote", boolean(0))
  return element {node-name($decoDesc)} {$decoNotes}
};

declare function mss:update-additions($additions as node()+) as node() {
  let $additionsList := element {node-name($additions/tei:list)} {mss:enumerate-element-sequence($additions/tei:list/tei:item, "addition", boolean(1))}
  return element {node-name($additions)} {$additions/tei:p, $additionsList}
};

declare function mss:update-ms-history($msHistory as node()+) as node() {
  (: perhaps just return the history node since we aren't doing processing right now? :)
};

declare function mss:update-ms-additional($recId as xs:string) as node() {
  let $recId := functx:substring-after-if-contains($recId, $config:uri-base)
  let $entryCitedRange := element {QName("http://www.tei-c.org/ns/1.0", "citedRange")} {attribute {"unit"} {"entry"}, decoder:get-decoder-data-from-uri($recId, "wrightRomanNumeral")}
  let $pageCitedRange := mss:create-page-citedRange-element($recId)
  let $oldBibl := $config:project-config/config//tei:msDesc/tei:additional/tei:listBibl/tei:bibl
  let $updatedBibl := element {QName("http://www.tei-c.org/ns/1.0", "bibl")} {$oldBibl/@*, $oldBibl/*, $entryCitedRange, $pageCitedRange}
  let $updatedListBibl := element {QName("http://www.tei-c.org/ns/1.0", "listBibl")} {$updatedBibl}
  return element {QName("http://www.tei-c.org/ns/1.0", "additional")} {$config:project-config/config//tei:msDesc/tei:additional/*[not(self::tei:listBibl)], $updatedListBibl}
};

declare function mss:create-page-citedRange-element($recId as xs:string) as node() {
  let $msLocationInCatalogue := decoder:get-decoder-data-from-uri($recId, "wrightCatalogLocation")
  let $pageCitedRange := fn:replace($msLocationInCatalogue, "#", ":")
  return element {QName("http://www.tei-c.org/ns/1.0", "citedRange")} {attribute {"unit"} {"pp"}, $pageCitedRange}
};

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
      let $keyWordRefValues := if(fn:string($keyword/@scheme) = "#Wright-BL-Taxonomy") then decoder:get-wright-taxonomy-id-from-uri($recId) else fn:string($keyword//tei:item/tei:ref[1])
      return mss:create-keywords-node(fn:string($keyword/@scheme), $keyWordRefValues, "")
  return element {QName("http://www.tei-c.org/ns/1.0", "textClass")} {$keywordsSeq}
};

declare function mss:create-keywords-node($keywordSchemeValue as xs:string, $keywordTargetValues as xs:string+, $msPartDesignations as xs:string*) as node() {
  let $keywordSchemeValue := functx:substring-after-if-contains($keywordSchemeValue, "#")
  let $items := for $value at $i in $keywordTargetValues
    let $valueRef := element {QName("http://www.tei-c.org/ns/1.0", "ref")} {attribute {"target"} {"#"||$value}}
    let $partRef := if($msPartDesignations[$i] != "") then element {QName("http://www.tei-c.org/ns/1.0", "ref")} {attribute {"target"} {"#"||$msPartDesignations[$i]}} else ()
    return  element {QName("http://www.tei-c.org/ns/1.0", "item")} {$valueRef, $partRef}
  let $list :=  element {QName("http://www.tei-c.org/ns/1.0", "list")} {$items}
  return  element {QName("http://www.tei-c.org/ns/1.0", "keywords")} {attribute {"scheme"} {"#"||$keywordSchemeValue}, $list}
};
 (: refactor this to work with msParts. It should instead be: 
- get wright taxonomy value
- call a generic 'create-keyword-node' function that takes a string vlaue for the scheme attr; a sequence of strings for the target attributes and a sequence of strings (optional) for part designations. 
- you'd then have to refactor the above function's switch statement perhaps. I suppose if you allow the create-wright-taxonomy-node function to accept a list of strings and an optional sequence of msParts this could work here as well where you just loop through the recId list and check if there is a matching msPart id each time. If there is, add it, if not, leave out that ref. In msParts you'd just be looking up in the decoder rather than supplying from the source docs which is less than ideal.
:)
(: Build revisionDesc :)

declare function mss:update-revisionDesc($revisionDesc as node()+) as node() {
  let $currentDate := fn:current-date()
  let $currentDate := fn:substring(xs:string($currentDate), 1, 10)
  let $newChangeLogElement := element {QName("http://www.tei-c.org/ns/1.0", "change")} {attribute {"who"} {$config:editors-document-uri||"#"||$config:change-log-script-id}, attribute {"when"} {$currentDate}, $config:change-log-message}
   return element {QName("http://www.tei-c.org/ns/1.0", "revisionDesc")} {$revisionDesc/@*, $newChangeLogElement, $revisionDesc/*}
};

(: Build tei:fascimile and tei:text :)

(: Note: as currently we are not using non-header elements (saving fascimile and text for later phases, perhaps with transcriptions when available), we are just returning these from the xml stub file in which the catalogue info was encoded. :)
declare function mss:update-tei-text-elements($doc as node()+) as node()+ {
  let $nonHeaderElements := ($doc/tei:TEI/tei:facsimile, $doc/tei:TEI/tei:text)
  return <nonHeaderElements>{$nonHeaderElements}</nonHeaderElements>
};

(:----------------------
: Functions for updating elements' xml:id values
: ------------------------:)

declare function mss:update-xml-id-values($doc as node(), $hasMsParts as xs:boolean)
as item()+ (: returns a sequence of a document-node() representing the updated record and a node() representing an index of updates needing to be propagated to existing data (e.g., cross-references to specific msItems) :)
{
  (: note: handle msParts! Maybe have a for loop where you pass the msPart to this function with a 'false ()' hasMsParts value.
  Then you can collect a sequence of msParts. Hmm this needs thought but might work? Essentially have the msParts processed normally and then you have a similar flag to control how everything is put together in the last stage?
   :)
  let $index := ()
  
  (: update the msItems in msContents :)
  let $temp := mss:update-msContents-xml-id-values($doc//tei:msDesc/tei:msContents)
  let $newMsContents := $temp[1]
  let $index := ($index, $temp[position()>1]) (: index is continuously collated from each update function :)
  
  (: update the handNotes in handDesc :)
  let $temp := mss:update-handDesc-xml-id-values($doc//tei:msDesc/tei:physDesc/tei:handDesc)
  let $newHandDesc := $temp[1]
  let $index := ($index, $temp[position()>1])
    
  (: update the decoNotes in decoDesc :)
  let $temp := if($doc//tei:msDesc/tei:physDesc/tei:decoDesc) then mss:update-decoDesc-xml-id-values($doc//tei:msDesc/tei:physDesc/tei:decoDesc) else ()
  let $newDecoDesc := if($doc//tei:msDesc/tei:physDesc/tei:decoDesc) then $temp[1] else $doc//tei:msDesc/tei:physDesc/tei:decoDesc
  let $index := ($index, $temp[position()>1])
  
  (: update the items in additions :)
  let $temp := if($doc//tei:msDesc/tei:physDesc/tei:additions) then mss:update-additions-xml-id-values($doc//tei:msDesc/tei:physDesc/tei:additions) else()
  let $newAdditions := if($doc//tei:msDesc/tei:physDesc/tei:additions) then $temp[1] else $doc//tei:msDesc/tei:physDesc/tei:additions
  let $index := ($index, $temp[position()>1])
  
  (: build the new file from updated components :)
  let $oldPhysDesc := $doc//tei:msDesc/tei:physDesc
  let $newPhysDesc := element {node-name($oldPhysDesc)} {$oldPhysDesc/@*,
                                                         $oldPhysDesc/tei:objectDesc,
                                                         $newHandDesc,
                                                         $newDecoDesc,
                                                         $newAdditions}
  let $oldMsDesc := $doc//tei:msDesc
  let $newMsDesc := element {node-name($oldMsDesc)} {$oldMsDesc/@*,
                                                     $oldMsDesc/tei:msIdentifier,
                                                     $newMsContents,
                                                     $newPhysDesc,
                                                     $oldMsDesc/tei:history,
                                                     $oldMsDesc/tei:additional
                                                     }
  let $newSourceDesc := element {node-name($doc//tei:sourceDesc)} {$newMsDesc}
  
  let $oldFileDesc := $doc//tei:fileDesc
  let $newFileDesc := element {node-name($oldFileDesc)} {$oldFileDesc/@*,
                                                         $oldFileDesc/tei:titleStmt,
                                                         $oldFileDesc/tei:editionStmt,
                                                         $oldFileDesc/tei:publicationStmt,
                                                         $newSourceDesc}
 
 let $oldTeiHeader := $doc//tei:teiHeader
 let $newTeiHeader := element {node-name($oldTeiHeader)} {$oldTeiHeader/@*,
                                                          $newFileDesc,
                                                          $oldTeiHeader/tei:encodingDesc,
                                                          $oldTeiHeader/tei:profileDesc,
                                                          $oldTeiHeader/tei:revisionDesc
                                                          }
 let $newRecord := element {QName("http://www.tei-c.org/ns/1.0", "TEI")} {attribute {"xml:lang"} {"en"},
                                                                          $newTeiHeader,
                                                                         $doc/tei:TEI/*[not(name() = "teiHeader")]}
 let $newDoc := document {$doc/processing-instruction(), $newRecord}
 
 return ($newDoc, $index)
};

declare function mss:update-msContents-xml-id-values($msContents as node())
as item()+ {
  
  (: add deprecatedId attributes based on current xml:id values :)
  let $msItems := $msContents/tei:msItem
  let $oldMsItemsWithDeprecatedIds := mss:add-deprecatedId-attributes-deep($msItems, "msItem") (: currently assuming we are comparing xml:id values; will be difficult to do otherwise :)
  
  (: remove xml:id and n attributes :)
  let $msItemsWithOnlyDeprecatedIds := functx:remove-attributes-deep($oldMsItemsWithDeprecatedIds, "xml:id") (: I think this is okay since only msItem children will have xml:ids; no notes, rubrics, etc. should have them? :)
  let $msItemsWithOnlyDeprecatedIds := functx:remove-attributes-deep($msItemsWithOnlyDeprecatedIds, "n")
  
  (: renumber and re-identify msItems :)
  let $msItemsWithNewAndDeprecatedIds := mss:add-msItem-id-and-enumeration-values(<msItemContainer>{$msItemsWithOnlyDeprecatedIds}</msItemContainer>, $mss:initial-msItem-up-stack, $mss:initial-msItem-down-stack, 1)[1]/tei:msItem
  
  (: create the index of attribute updates :)
  let $index := mss:create-index-of-xml-id-updates($msItemsWithNewAndDeprecatedIds, (), "msItem")

  (: remove the deprecatedId attributes as they are no longer needed :)
  let $updatedMsItems := functx:remove-attributes-deep($msItemsWithNewAndDeprecatedIds, "deprecatedId")
  
  (: build the new msContents element from the updated msItem sequence :)
  let $newMsContents := element {node-name($msContents)} {$msContents/@*, 
                                                          $msContents/tei:summary,
                                                          $msContents/tei:textLang,
                                                          $updatedMsItems}
  return ($newMsContents, $index)
};

declare function mss:update-handDesc-xml-id-values($handDesc as node())
as item()+ {
  (: add deprecatedId attributes based on current xml:id values :)
  let $handNotes := $handDesc/tei:handNote
  let $oldHandNotesWithDeprecatedIds :=  mss:add-deprecatedId-attributes-deep($handNotes, "handNote")
  
  (: remove xml:id attributes :)
  let $handNotesWithOnlyDeprecatedIds := functx:remove-attributes-deep($oldHandNotesWithDeprecatedIds, "xml:id")
  
  (: re-identify msItems :)
  let $handNotesWithNewAndDeprecatedIds := mss:enumerate-element-sequence($handNotesWithOnlyDeprecatedIds, "handNote", fn:boolean(0))
  
  (: create the index of attribute updates :)
  let $index := mss:create-index-of-xml-id-updates($handNotesWithNewAndDeprecatedIds, (), "handNote")

  (: remove the deprecatedId attributes as they are no longer needed :)
  let $updatedHandNotes := functx:remove-attributes-deep($handNotesWithNewAndDeprecatedIds, "deprecatedId")
  
  (: build the new handDesc element from the updated msItem sequence :)
  let $newHandDesc := element {node-name($handDesc)} {$handDesc/@*, 
                                                          $updatedHandNotes}
  
  return $newHandDesc
};

(: REFACTOR. This is a carbon copy of the handDesc update with 'hand' changed to 'deco'...:)
declare function mss:update-decoDesc-xml-id-values($decoDesc as node())
as item()+ {
  (: add deprecatedId attributes based on current xml:id values :)
  let $decoNotes := $decoDesc/tei:decoNote
  let $oldDecoNotesWithDeprecatedIds :=  mss:add-deprecatedId-attributes-deep($decoNotes, "decoNote")
  
  (: remove xml:id attributes :)
  let $decoNotesWithOnlyDeprecatedIds := functx:remove-attributes-deep($oldDecoNotesWithDeprecatedIds, "xml:id")
  
  (: re-identify msItems :)
  let $decoNotesWithNewAndDeprecatedIds := mss:enumerate-element-sequence($decoNotesWithOnlyDeprecatedIds, "decoNote", boolean(0))
  
  (: create the index of attribute updates :)
  let $index := mss:create-index-of-xml-id-updates($decoNotesWithNewAndDeprecatedIds, (), "decoNote")

  (: remove the deprecatedId attributes as they are no longer needed :)
  let $updatedDecoNotes := functx:remove-attributes-deep($decoNotesWithNewAndDeprecatedIds, "deprecatedId")
  
  (: build the new handDesc element from the updated msItem sequence :)
  let $newDecoDesc := element {node-name($decoDesc)} {$decoDesc/@*, 
                                                          $updatedDecoNotes}
  
  return $newDecoDesc
};

declare function mss:update-additions-xml-id-values($additions as node())
as item()+ {
  (: add deprecatedId attributes based on current xml:id values :)
  let $additionItems := $additions/tei:list/tei:item
  let $oldAdditionItemsWithDeprecatedIds :=  mss:add-deprecatedId-attributes-deep($additionItems, "item")
  
  (: remove xml:id and n attributes :)
  let $additionItemsWithOnlyDeprecatedIds := functx:remove-attributes-deep($oldAdditionItemsWithDeprecatedIds, "xml:id")
  let $additionItemsWithOnlyDeprecatedIds := functx:remove-attributes-deep($additionItemsWithOnlyDeprecatedIds, "n")

  (: re-identify msItems :)
  let $additionItemsWithNewAndDeprecatedIds := mss:enumerate-element-sequence($additionItemsWithOnlyDeprecatedIds, "addition", boolean(1))
  
  (: create the index of attribute updates :)
  let $index := mss:create-index-of-xml-id-updates($additionItemsWithNewAndDeprecatedIds, (), "item")

  (: remove the deprecatedId attributes as they are no longer needed :)
  let $updatedAdditionItems := functx:remove-attributes-deep($additionItemsWithNewAndDeprecatedIds, "deprecatedId")
  
  (: build the new handDesc element from the updated msItem sequence :)
  let $newAdditionsList := element {node-name($additions/tei:list)} {$updatedAdditionItems}
  let $newAdditions := element {node-name($additions)} {$additions/@*, 
                                                        $additions/tei:p,
                                                        $newAdditionsList}
  
  return $newAdditions
};

declare function mss:add-deprecatedId-attributes-deep($nodes as node()*, $elementName as xs:string)
as node()* {
  for $node in $nodes
  let $deprecatedIdValue := string($node/@xml:id)
  return if($node instance of element())
         then element {node-name($node)}
               {$node/@*, attribute {"deprecatedId"} {$deprecatedIdValue},
               $node/*[not(name() = $elementName)],
               mss:add-deprecatedId-attributes-deep($node/*[name() = $elementName], $elementName)}
};

declare function mss:create-index-of-xml-id-updates($nodes as node()*, $currentIndex as node()*, $elementName as xs:string)
as node()*
{
  let $newIndex :=
     for $node in $nodes
     let $updateList := if(string($node/@xml:id) != string($node/@deprecatedId) (: if there was a change in ID :)
                           and string($node/@deprecatedId) != "") (: and if there was an old ID that changed :)
                        then
                        <update>
                          <oldId>{string($node/@deprecatedId)}</oldId>
                          <newId>{string($node/@xml:id)}</newId>
                        </update>
    (: append the ID updates of child nodes to the current update list (since $updateList is passed as the $currentIndex, the updates from the descendants get returned appended to the parent node as the '$newIndex') :)
    return mss:create-index-of-xml-id-updates($node/*[name() = $elementName], $updateList, $elementName)
 return ($currentIndex, $newIndex)
};