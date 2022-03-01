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
import module namespace msParts="http://srophe.org/srophe/msParts" at "msParts.xqm";
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
  
  let $shelfMarkNumber := if (contains(lower-case($shelf-mark), "fo")) then substring-before(lower-case($shelf-mark), " fo") else $shelf-mark (: ignore any suffix foll. designation :)
  let $shelfMarkNumber := string-join(functx:get-matches($shelfMarkNumber, "\d+"), "")
  
  let $shelfMarkSuffix := if (contains(lower-case($shelf-mark), "fo")) then "fo"||substring-after(lower-case($shelf-mark), "fo") else ""
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

declare function mss:remove-empty-attributes-in-node-sequence-recursive($node-seq as element()*)
as element()*
{
  for $node in $node-seq
  let $nonEmptyAttrs :=
    for $attr in $node/@*
    return if(string($attr) != "") then $attr
    return element {node-name($node)} {$nonEmptyAttrs, 
    for $child in $node/node()
    return if ($child instance of element())
     then mss:remove-empty-attributes-in-node-sequence-recursive($child)
     else $child}
};

declare function mss:remove-empty-children-in-node-sequence-msItem-recursive($node-seq as element()*)
as element()*
{
  for $node in $node-seq
  let $nonEmptyChildren :=
    for $el in $node/*
    let $text := string-join($el//text(), "")
    return 
      if(local-name($el) = "msItem") then mss:remove-empty-children-in-node-sequence-msItem-recursive($el) (: recurse on msItem elements :)
      else if(normalize-space($text) != "") then $el (: non-msItem elements with descendant text should be kept :)
      else if(local-name($el) = "locus" and ($el/@from or $el/@to)) then $el (: locus elements are kept only if they have a @from or @to attribute :)
  return element {node-name($node)} {$node/@*, $nonEmptyChildren}
};

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
  let $updatedMsDesc := element {QName("http://www.tei-c.org/ns/1.0", "msDesc")} {attribute {"xml:id"} {"manuscript-"||$msId}, $msIdentifier, $msContents, $physDesc, $history, $additional}
  return mss:remove-empty-attributes-in-node-sequence-recursive($updatedMsDesc)
  
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
  let $msItems := mss:remove-empty-attributes-in-node-sequence-recursive($msItems)
  let $msItems := mss:remove-empty-children-in-node-sequence-msItem-recursive($msItems)
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
  let $additions := mss:remove-empty-attributes-in-node-sequence-recursive($additions)
  let $additionsItemsWithoutEmptyItems := mss:remove-empty-children-in-node-sequence-msItem-recursive($additions/tei:list/tei:item)
  let $additionsList := element {node-name($additions/tei:list)} {$additionsItemsWithoutEmptyItems}
  let $additionsListWithoutEmptyItems := mss:remove-empty-children-in-node-sequence-msItem-recursive($additionsList)
  let $additionsList := if(count($additionsListWithoutEmptyItems/tei:item) > 0) then element {node-name($additions/tei:list)} {mss:enumerate-element-sequence($additionsListWithoutEmptyItems/tei:item, "addition", boolean(1))}
  else ()
  let $additions := element {node-name($additions)} {$additions/tei:p, $additionsList}
  return  mss:remove-empty-children-in-node-sequence-msItem-recursive($additions)
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
    let $valueRef := element {QName("http://www.tei-c.org/ns/1.0", "ref")} {attribute {"target"} {"#"||functx:substring-after-if-contains($value, "#")}}
    let $partRef := if($msPartDesignations[$i] != "") then element {QName("http://www.tei-c.org/ns/1.0", "ref")} {attribute {"target"} {"#"||functx:substring-after-if-contains($msPartDesignations[$i], "#")}} else ()
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
  let $newChangeLog := mss:remove-empty-attributes-in-node-sequence-recursive(($newChangeLogElement, $revisionDesc/*))
   return element {QName("http://www.tei-c.org/ns/1.0", "revisionDesc")} {$revisionDesc/@*, $newChangeLog}
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

declare function mss:update-document-xml-id-values($doc as node())
as item()+ (: returns a sequence of a document-node() representing the updated record and a node() representing an index of updates needing to be propagated to existing data (e.g., cross-references to specific msItems) :)
{
  let $hasMsPart := if($doc//tei:msPart) then true () else false ()
  let $temp := mss:update-msDesc-xml-id-values($doc//tei:sourceDesc/tei:msDesc, $hasMsPart, "")
  let $newMsDesc := $temp[1]
  let $index := $temp[position() > 1]

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

(:~ 
: @author William L. Potter
: @version 1.1
: 
: Returns two items. 1.) a tei:msDesc element with xml:ids updated based on
: the outline of child msPart elements.
: The IDs are constructed using "Part" and then a sequential integer.
: Layers of nested msParts accrue "_" separated integer sequences, e.g. "Part1_3_2"
: The xml:ids of the nested msItem, handNote, addition items, etc. are also updated
: using a prefix ID, e.g. "p1_3_2a1" for an msItem.
: 
: This script can handle n-levels of msPart nesting.
:
:)

declare function mss:update-msDesc-xml-id-values($msDesc as node(), $hasMsParts as xs:boolean, $idPrefix as xs:string?)
as item()+
{
  let $index := ()
  return 
  (: if the msDesc is made up of one or more msParts, process those as if they were msDesc nodes :)
    if ($hasMsParts) then 
    let $msPartsAndIndex := 
      for $msPart at $i in $msDesc/tei:msPart
      let $partIdPrefix := if($idPrefix = "") then "p" || $i else $idPrefix || "_" || $i
      return mss:update-msDesc-xml-id-values($msPart, boolean($msPart/tei:msPart), $partIdPrefix)
  (: split out the msPart elements and the index element for the updates :)
    let $index := $msPartsAndIndex/self::*:part
    let $msParts := $msPartsAndIndex/self::tei:msPart
    
  (: if the node is an msPart, give it an xml:id of the form "Partx_y", depending on its level in the nest. Otherwise use the msDesc ID :)
  let $partId := "Part"||substring-after($idPrefix, "p")
  let $descId := if(name($msDesc) = "msPart") then attribute {"xml:id"} {$partId} else $msDesc/@xml:id
  
  (: if the node is an msPart, give an @n value of the form "x.y", depending on its position in the sequence and in the outline. If it is an msDesc, do not give it an @n value :)
  let $partNumber := substring-after($idPrefix, "p")
  let $partNumber := replace($partNumber, "_", ".")
  let $nAttr := if(name($msDesc) = "msPart") then attribute {"n"} {$partNumber}
  
  (: build the updated msDesc element from the msParts and return along with the index :)
    let $newMsDesc := element {node-name($msDesc)} {$descId, $nAttr, $msDesc/@*[not(name() = "xml:id") and not(name() = "n")],
                                                     $msDesc/tei:msIdentifier,
                                                     $msParts
                                                   }
  (: add the nested part indices to the index for this level :)
    let $index := <part uri="{$msDesc/tei:msIdentifier/tei:idno/text()}">{$index}</part>
    return ($newMsDesc, $index)
    
    (: if the node does not have nested msParts (i.e., it is an msPart itself or it is a simple msDesc), process it as normal :)
    else
    
    (: update the msItems in msContents :)
    let $msContentsData := mss:update-msContents-xml-id-values($msDesc/tei:msContents, $idPrefix)
    let $newMsContents := $msContentsData[1]
    let $index := ($index, $msContentsData[position()>1]) (: index is continuously collated from each update function :)
  
    (: update the handNotes in handDesc :)
    let $handDescData := mss:update-handDesc-xml-id-values($msDesc/tei:physDesc/tei:handDesc, $idPrefix)
    let $newHandDesc := $handDescData[1]
    let $index := ($index, $handDescData[position()>1])
    
    (: update the decoNotes in decoDesc :)
    let $decoDescData := if($msDesc/tei:physDesc/tei:decoDesc[decoNote]) then mss:update-decoDesc-xml-id-values($msDesc/tei:physDesc/tei:decoDesc, $idPrefix) else ()
    let $newDecoDesc := if($msDesc/tei:physDesc/tei:decoDesc) then $decoDescData[1] else $msDesc/tei:physDesc/tei:decoDesc
    let $index := ($index, $decoDescData[position()>1])
  
  (: update the items in additions :)
  let $additionsData := if($msDesc/tei:physDesc/tei:additions/tei:list/tei:item) then mss:update-additions-xml-id-values($msDesc/tei:physDesc/tei:additions, $idPrefix) else()
  let $newAdditions := if($msDesc/tei:physDesc/tei:additions/tei:list/tei:item) then $additionsData[1] else $msDesc/tei:physDesc/tei:additions
  let $index := ($index, $additionsData[position()>1])
  
  (: build the new msDesc from updated components :)
  let $oldPhysDesc := $msDesc/tei:physDesc
  let $newPhysDesc := element {node-name($oldPhysDesc)} {$oldPhysDesc/@*,
                                                         $oldPhysDesc/tei:objectDesc,
                                                         $newHandDesc,
                                                         $newDecoDesc,
                                                         $newAdditions,
                                                         (: for now have these last two pass as-is. If we start adding this info we will need to pass this instead to the update id function :)
                                                         $oldPhysDesc/tei:bindingDesc,
                                                         $oldPhysDesc/tei:sealDesc,
                                                         $oldPhysDesc/tei:accMat}
  let $newAdditional := msParts:add-part-designation-to-additional($msDesc/tei:additional, substring-after($idPrefix, "p"))                                                       
  (: if the node is an msPart, give it an xml:id of the form "Partx_y", depending on its level in the nest. Otherwise use the msDesc ID :)
  let $partId := "Part"||substring-after($idPrefix, "p")
  let $descId := if(name($msDesc) = "msPart") then attribute {"xml:id"} {$partId} else $msDesc/@xml:id
  
  (: if the node is an msPart, give an @n value of the form "x.y", depending on its position in the sequence and in the outline. If it is an msDesc, do not give it an @n value :)
  let $partNumber := substring-after($idPrefix, "p")
  let $partNumber := replace($partNumber, "_", ".")
  let $nAttr := if(name($msDesc) = "msPart") then attribute {"n"} {$partNumber}
  
  
  let $newMsDesc := element {node-name($msDesc)} {$descId, $nAttr, $msDesc/@*[not(name() = "xml:id") and not(name() = "n")],
                                                     $msDesc/tei:msIdentifier,
                                                     $newMsContents,
                                                     $newPhysDesc,
                                                     $msDesc/tei:history,
                                                     $newAdditional
                                                     }
   (: nest the update index for this part into a part-level index :)
    let $index := <part uri="{$msDesc/tei:msIdentifier/tei:idno/text()}">{$index}</part>  
  return ($newMsDesc, $index)
};

(:~ 
: Returns two items: a sequence of elements nested in a <container/> element
: with xml:ids updated based on elementName; and an index of <update/> elements
: nested in a <container/> element recording the old and updated xml:id values
: for each element.
: 
: @param $nodes is the sequence of elements with old IDs needing to be updated
: @param $elementName is a string containing the local name of the targeted element,
: e.g., "msItem". This is used both to specify which nodes (especially descendant nodes)
: to process and serves as the input for the switch statement controlling how the xml:ids
: are re-calculated.
: @param $idPrefix is an optional string that is passed to the recalculation functions
: to allow this function to be used on msPart items.
:
:)
declare function mss:update-xml-id-values-deep($nodes as node()+, $elementName as xs:string, $idPrefix as xs:string?) 
as node()+
{
  (: add deprecatedId attributes based on current xml:id values :)
  let $oldNodesWithDeprecatedIds := mss:add-deprecatedId-attributes-deep($nodes, $elementName)
  
  (: remove xml:id and n attributes :)
  let $nodesWithOnlyDeprecatedIds := functx:remove-attributes-deep($oldNodesWithDeprecatedIds, "xml:id")
  let $nodesWithOnlyDeprecatedIds := functx:remove-attributes-deep($nodesWithOnlyDeprecatedIds, "n")
  
  (: renumber and re-identify msItems :)
  (: use a switch statement for msItem (has its own function), additions (needs the 'true' of n value), default (handNote, decoNote, seal, binding, etc.):)
  let $nodesWithNewAndDeprecatedIds :=
    switch ($elementName)
    case "msItem" return 
      mss:add-msItem-id-and-enumeration-values(<msItemContainer>{$nodesWithOnlyDeprecatedIds}</msItemContainer>, 
                                               $mss:initial-msItem-up-stack, 
                                               $mss:initial-msItem-down-stack, 
                                               1)[1]/tei:msItem
    case "item" return (: for additions :)
      mss:enumerate-element-sequence($nodesWithOnlyDeprecatedIds, 
                                     "addition", 
                                     true ())
    default return (: for handNote, decoNote, seal, and binding elements :)
      mss:enumerate-element-sequence($nodesWithOnlyDeprecatedIds, 
                                     $elementName, 
                                     false ())
                                     
  (: add the ID prefix to the xml:ids in the sequence :)
  let $nodesWithNewAndDeprecatedIds :=
     msParts:add-part-designation-to-element-sequence($nodesWithNewAndDeprecatedIds, "", $idPrefix) (: this isn't ideal. Refactor to have an 'add-id-prefix-to-elements-deep' function in the mss namespace; call this in the msParts namespace :)
  (: create the index of attribute updates :)
  let $index := mss:create-index-of-xml-id-updates($nodesWithNewAndDeprecatedIds,
                                                   (),
                                                   $elementName)
  
  (: remove the deprecatedId attributes as they are no longer needed :)
  let $updatedNodes := functx:remove-attributes-deep($nodesWithNewAndDeprecatedIds, 
                                                     "deprecatedId")
                                                     
  (: return the updated sequence of nodes and the newly built index. :)
  return (<container>{$updatedNodes}</container>, <container>{$index}</container>)
};

declare function mss:update-msContents-xml-id-values($msContents as node(), $idPrefix as xs:string?)
as item()+ {
  
  let $msItems := $msContents/tei:msItem
  let $temp := mss:update-xml-id-values-deep($msItems, "msItem", $idPrefix)
  let $updatedMsItems := $temp[1]/* (: return the msItem sequence from the function return's first container :)
  let $index := $temp[2]/* (: return the index of updated ids from the function return's second container :)
  
  (: build the new msContents element from the updated msItem sequence :)
  let $newMsContents := element {node-name($msContents)} {$msContents/@*, 
                                                          $msContents/tei:summary,
                                                          $msContents/tei:textLang,
                                                          $updatedMsItems}
  return ($newMsContents, $index)
};

declare function mss:update-handDesc-xml-id-values($handDesc as node(), $idPrefix as xs:string?)
as item()+ {
  
  let $handNotes := $handDesc/tei:handNote
  let $temp := mss:update-xml-id-values-deep($handNotes, "handNote", $idPrefix)
  let $updatedHandNotes := $temp[1]/* (: return the handNote sequence from the function return's first container :)
  let $index := $temp[2]/* (: return the index of updated ids from the function return's second container :)
  
  (: build the new handDesc element from the updated msItem sequence :)
  let $newHandDesc := element {node-name($handDesc)} {$handDesc/@*, 
                                                          $updatedHandNotes}
  
  return ($newHandDesc, $index)
};

declare function mss:update-decoDesc-xml-id-values($decoDesc as node(), $idPrefix as xs:string?)
as item()+ {
  let $decoNotes := $decoDesc/tei:decoNote
  let $temp := mss:update-xml-id-values-deep($decoNotes, "decoNote", $idPrefix)
  let $updatedDecoNotes := $temp[1]/* (: return the decoNote sequence from the function return's first container :)
  let $index := $temp[2]/* (: return the index of updated ids from the function return's second container :)
  
  (: build the new handDesc element from the updated msItem sequence :)
  let $newDecoDesc := element {node-name($decoDesc)} {$decoDesc/@*, 
                                                          $updatedDecoNotes}
  
  return ($newDecoDesc, $index)
};

declare function mss:update-additions-xml-id-values($additions as node(), $idPrefix as xs:string?)
as item()+ {
  
  let $additionItems := $additions/tei:list/tei:item
  let $temp := mss:update-xml-id-values-deep($additionItems, "item", $idPrefix)
  let $updatedAdditionItems := $temp[1]/* (: return the handNote sequence from the function return's first container :)
  let $index := $temp[2]/* (: return the index of updated ids from the function return's second container :)
  
  (: build the new handDesc element from the updated msItem sequence :)
  let $newAdditionsList := element {node-name($additions/tei:list)} {$updatedAdditionItems}
  let $newAdditions := element {node-name($additions)} {$additions/@*, 
                                                        $additions/tei:p,
                                                        $newAdditionsList}
  
  return ($newAdditions, $index)
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
                           (: and string($node/@deprecatedId) != "" :)) (: and if there was an old ID that changed -- commented out for testing purposes :)
                        then
                        <update timeStamp="{string(current-dateTime())}">
                          <oldId>{string($node/@deprecatedId)}</oldId>
                          <newId>{string($node/@xml:id)}</newId>
                        </update>
    (: append the ID updates of child nodes to the current update list (since $updateList is passed as the $currentIndex, the updates from the descendants get returned appended to the parent node as the '$newIndex') :)
    return mss:create-index-of-xml-id-updates($node/*[name() = $elementName], $updateList, $elementName)
 return ($currentIndex, $newIndex)
};