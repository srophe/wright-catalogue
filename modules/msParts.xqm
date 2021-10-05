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


(: ---------------------------- :)
(: Global variable declarations :)
(: ---------------------------- :)

declare variable $msParts:config-msParts :=
  let $pathToConfig := $config:path-to-repo || "/parameters/config-msParts.xml"
  return fn:doc($pathToConfig);

declare variable $msParts:path-to-msParts-folder :=
  $config:path-to-repo || $msParts:config-msParts/config/manuscriptLevelMetadata/pathToMsPartsFolder/text();
  
declare variable $msParts:manuscript-part-source-document-sequence :=
  for $file in $msParts:config-msParts/config/msPartFiles/fileName
    let $fullFilePath := $msParts:path-to-msParts-folder || $file/text()
    return fn:doc($fullFilePath);
   
declare variable $msParts:record-title :=
  $msParts:config-msParts/config/manuscriptLevelMetadata/recordTitle/text();
   
declare variable $msParts:ms-level-shelfmark :=
  $msParts:config-msParts/config/manuscriptLevelMetadata/shelfMark/text();
  
declare variable $msParts:ms-level-uri :=
  let $msLevelId := $msParts:config-msParts/config/manuscriptLevelMetadata/uriValue/text()
  return $config:uri-base || $msLevelId;
    
(: -------------------------------------------------------- :)
(: Create document node of full record from component parts :)
(: -------------------------------------------------------- :)

declare function msParts:create-composite-document($msPartsDocumentSequence as node()+) as node() {
  (: the first record in the msParts sequence serves as the template for all data shared between msPart records :)
  let $templateDocument := $msPartsDocumentSequence[1]

  (: get all shared data from template :)
  let $processingInstructions := $templateDocument/processing-instruction()
  let $editionStmt := $templateDocument//tei:editionStmt
  let $encodingDesc := $templateDocument//tei:encodingDesc
  let $langUsage := $templateDocument//tei:profileDesc/tei:langUsage
  let $facsimile := $templateDocument//tei:facsimile
  let $textElement := $templateDocument//tei:text
  
  (: build other components from functions :)
  let $titleStmt := msParts:create-merged-titleStmt($msPartsDocumentSequence)
  let $publicationStmt := msParts:create-publicationStmt($msParts:config-msParts/config/manuscriptLevelMetadata/uriValue/text())
  let $msDesc := msParts:update-msDesc($msPartsDocumentSequence)
  let $textClass := msParts:create-merged-textClass($msPartsDocumentSequence)
  let $revisionDesc := msParts:create-merged-revisionDesc($msPartsDocumentSequence)
  
  (: build out document from components :)
  let $sourceDesc := element {QName("http://www.tei-c.org/ns/1.0", "sourceDesc")} {$msDesc}
  
  let $fileDesc := element {QName("http://www.tei-c.org/ns/1.0", "fileDesc")} {$titleStmt, $editionStmt, $publicationStmt, $sourceDesc}
  let $profileDesc := element {QName("http://www.tei-c.org/ns/1.0", "profileDesc")} {$langUsage, $textClass}
  
  let $teiHeader := element {QName("http://www.tei-c.org/ns/1.0", "teiHeader")} {$fileDesc, $encodingDesc, $profileDesc, $revisionDesc}
  
  let $documentNode := element {QName("http://www.tei-c.org/ns/1.0", "TEI")} {$teiHeader, $facsimile, $textElement}
  
  (: return document node based on built components :)
  return document {$processingInstructions, $documentNode}
  
};

(: -------------------------- :)
(: Merge titleStmt components :)
(: -------------------------- :)

declare function msParts:merge-editor-list($documentSequence as node()+) as node()+ {
  let $allCreatorEditors := for $doc in $documentSequence
    return $doc//tei:titleStmt/tei:editor
  return functx:distinct-deep($allCreatorEditors)
};
  
declare function msParts:merge-respStmt-list($documentSequence as node()+) as node()+ {
  let $fullRespStmtList := $documentSequence//tei:respStmt
  let $creatorRespStmts := for $respStmt in $fullRespStmtList
    return if($respStmt/tei:resp/text() = "Created by") then $respStmt
  let $editorRespStmts := for $respStmt in $fullRespStmtList
    return if($respStmt/tei:resp/text() = "Edited by") then $respStmt
  let $projectManagerRespStmts := for $respStmt in $fullRespStmtList
    return if($respStmt/tei:resp/text() = "Project management by") then $respStmt
  
  let $updatedRespList := for $respStmt in $documentSequence[1]//tei:titleStmt/tei:respStmt
    let $respDesc := $respStmt/tei:resp/text()
    return switch ($respDesc)
      case "Created by" return $creatorRespStmts
      case "Edited by" return $editorRespStmts
      case "Project management by" return $projectManagerRespStmts
      default return $respStmt

  return functx:distinct-deep($updatedRespList)
};

declare function msParts:create-merged-titleStmt($documentSequence as node()+) as node() {
  let $titleStmtTemplate := $documentSequence[1]//tei:titleStmt
  let $recordTitle := $titleStmtTemplate/tei:title[@level="a"]
  let $recordTitle := element {node-name($recordTitle)} {$recordTitle/@*, $msParts:record-title}
  let $moduleTitle := $titleStmtTemplate/tei:title[@level="m"]
  let $mergedEditorList := msParts:merge-editor-list($documentSequence)
  let $mergedRespStmtList := msParts:merge-respStmt-list($documentSequence)
  
  (: Create the updated titleStmt element from the new record title, all the elements shared between the records, and the element and respStmt lists :)
  return element {node-name($titleStmtTemplate)} {$recordTitle, $moduleTitle, $titleStmtTemplate/*[not(name() = "title") and not(name() = "editor") and not(name() = "respStmt")], $mergedEditorList, $mergedRespStmtList}
};

declare function msParts:create-publicationStmt($uri as xs:string) as node() {
  let $uri := if (fn:starts-with($uri, "http")) then $uri||"/tei" else $config:uri-base||$uri||"/tei"
  
  let $templateRecord := $msParts:manuscript-part-source-document-sequence[1]
  let $templatePubStmt := $templateRecord//tei:publicationStmt
  let $idno := $templatePubStmt/tei:idno
  let $idno := element {fn:node-name($idno)} {$idno/@*, $uri}
  let $publicationDate := element {QName("http://www.tei-c.org/ns/1.0", "date")} {attribute {"calendar"} {"Gregorian"}, fn:current-date()}
  return element {fn:node-name($templatePubStmt)} {$templatePubStmt/tei:authority, $idno, $templatePubStmt/tei:availability, $publicationDate}
};

(: -------------------------------------------- :)
(: Updating manuscript description with msParts :)
(: -------------------------------------------- :)

declare function msParts:update-msDesc($msPartDocumentSequence as node()+) as node() {
  let $msDescId := "manuscript"||$msParts:config-msParts/config/manuscriptLevelMetadata/uriValue/text()
  let $msIdentifier := msParts:create-main-msIdentifier()
  let $msPartSeq := msParts:create-msPart-sequence($msPartDocumentSequence)
  return element {QName("http://www.tei-c.org/ns/1.0", "msDesc")} {attribute {"xml:id"} {$msDescId}, $msIdentifier, $msPartSeq}
};

declare function msParts:create-main-msIdentifier() {
  let $mainMsMetadata := $msParts:config-msParts/config/manuscriptLevelMetadata
  let $country := element {QName("http://www.tei-c.org/ns/1.0", "country")} {$mainMsMetadata/country/text()}
  let $settlement := element {QName("http://www.tei-c.org/ns/1.0", "settlement")} {$mainMsMetadata/settlement/text()}
  let $repository := element {QName("http://www.tei-c.org/ns/1.0", "repository")} {$mainMsMetadata/repository/text()}
  let $collection := element {QName("http://www.tei-c.org/ns/1.0", "collection")} {$mainMsMetadata/collection/text()}
  let $uriIdno := element {QName("http://www.tei-c.org/ns/1.0", "idno")} {attribute {"type"} {"URI"}, "https://syriaca.org/manuscript/"||$mainMsMetadata/uriValue/text()}
  let $shelfMarkIdno := element {QName("http://www.tei-c.org/ns/1.0", "idno")} {attribute {"type"} {"BL-Shelfmark"}, $mainMsMetadata/shelfMark/text()}
  let $altIdentifier := element {QName("http://www.tei-c.org/ns/1.0", "altIdentifier")} {$shelfMarkIdno}
  return element {QName("http://www.tei-c.org/ns/1.0", "msIdentifier")} {$country, $settlement, $repository, $collection, $uriIdno, $altIdentifier}
};

declare function msParts:create-msPart-sequence($msPartDocumentSequence as node()+) as node()+ {
  for $doc at $i in $msPartDocumentSequence (: figuring out how to handle adding them into existing msParts will be interesting. Potentially an 'update-msPart-sequence' function where you somehow specify the value of the part number and where within it you want it to go. Think more about htis.:)
    let $msPart := msParts:create-msPart($doc//tei:msDesc, $i)
    return element {QName("http://www.tei-c.org/ns/1.0", "msPart")} {$msPartDocumentSequence//tei:msDesc/*}
};

declare function msParts:create-msPart($singleMsDesc as node(), $partNumber as xs:string) as node() {
  let $msIdentifier := $singleMsDesc/tei:msIdentifier
  let $msContents := msParts:add-part-designation-to-msContents($singleMsDesc/tei:msContents, $partNumber)
  let $physDesc := msParts:add-part-designation-to-physDesc($singleMsDesc/tei:physDesc, $partNumber)
  let $history := $singleMsDesc/tei:history
  let $additional := msParts:add-part-designation-to-additional($singleMsDesc/tei:additional, $partNumber)
  return element {QName("http://www.tei-c.org/ns/1.0", "msPart")} {attribute {"xml:id"} {"Part"||$partNumber}, $msIdentifier, $msContents, $physDesc, $history, $additional}
};

declare function msParts:add-part-designation-to-element-sequence($elementSequence as node()*, $partNumber as xs:string, $idPrefix as xs:string) as node()* {
  (: all records are assumed to have an xml:id and be in the correct order, so you should have edited the files you are working on and also run a script that adds and renumbers the xml:ids so that they are in the correct sequence, etc. before running this function :)
  let $temp := ""
  return if(empty($elementSequence)) then ()
  else
  for $el in $elementSequence
    let $nodeName := fn:node-name($el)
    let $xmlId := fn:string($el/@xml:id)
    let $xmlId := $idPrefix||$partNumber||$xmlId
    return if ($el[fn:node-name() = $nodeName]) 
     then element {$nodeName} {attribute {"xml:id"} {$xmlId}, $el/@*[not(namespace-uri()='http://www.w3.org/XML/1998/namespace' and local-name()='id')], $el/*[not(fn:node-name() = $nodeName)], msParts:add-part-designation-to-element-sequence($el/*[fn:node-name() = $nodeName], $partNumber, $idPrefix)}
     else element {$nodeName} {attribute {"xml:id"} {$xmlId}, $el/@*[not(namespace-uri()='http://www.w3.org/XML/1998/namespace' and local-name()='id')], $el/*}
};

declare function msParts:add-part-designation-to-msContents($msContents as node(), $partNumber as xs:string) as node() {
  let $msItems := msParts:add-part-designation-to-element-sequence($msContents/tei:msItem, $partNumber, "p")
  return element {fn:node-name($msContents)} {$msContents/*[not(name()='msItem')], $msItems}
};

declare function msParts:add-part-designation-to-physDesc($physDesc as node(), $partNumber as xs:string) as node() {
    let $objectDesc := $physDesc/tei:objectDesc
    let $handDesc := $physDesc/tei:handDesc
    let $handDesc := element {fn:node-name($handDesc)} {$handDesc/@*, msParts:add-part-designation-to-element-sequence($handDesc/tei:handNote, $partNumber, "p")}
    let $decoDesc := if($physDesc/tei:decoDesc) then element {fn:node-name($physDesc/tei:decoDesc)} {$physDesc/tei:decoDesc/@*, msParts:add-part-designation-to-element-sequence($physDesc/tei:decoDesc/tei:decoNote, $partNumber, "p")}
    let $additions := if($physDesc/tei:additions/tei:list/tei:item) then msParts:add-part-designation-to-additions-items($physDesc/tei:additions, $partNumber)
      else element {QName("http://www.tei-c.org/ns/1.0", "additions")} {}
    let $bindingDesc := $physDesc/tei:bindingDesc (: as-is :)
    let $sealDesc := $physDesc/tei:sealDesc (: as-is :)
    let $accMat := $physDesc/tei:accMat
    return element {QName("http://www.tei-c.org/ns/1.0", "physDesc")} {$objectDesc, $handDesc, $decoDesc, $additions, $bindingDesc, $sealDesc, $accMat}
};

declare function msParts:add-part-designation-to-additions-items($additions as node(), $partNumber as xs:string) as node() {
  let $additionsList := element {fn:node-name($additions/tei:list)} {msParts:add-part-designation-to-element-sequence($additions/tei:list/tei:item, $partNumber, "p")}
  return element {fn:node-name($additions)} {$additions/*[not(name()= name($additionsList))], $additionsList}
};

declare function msParts:add-part-designation-to-additional($additional as node(), $partNumber as xs:string) as node() {
  let $wrightBibl := $additional/tei:listBibl/tei:bibl
  let $newBiblId := fn:string($wrightBibl/@xml:id)||"Part"||$partNumber
  let $newRecordHist := msParts:add-part-designation-to-recordHist($additional/tei:adminInfo/tei:recordHist, $newBiblId)
  let $adminInfo := element {fn:node-name($additional/tei:adminInfo)} {$newRecordHist, $additional/tei:adminInfo/tei:note}

  let $wrightBibl := element {fn:node-name($wrightBibl)} {attribute {"xml:id"} {$newBiblId}, $wrightBibl/*}
  let $listBibl := element {fn:node-name($additional/tei:listBibl)} {$wrightBibl}
  return element {fn:node-name($additional)} {$adminInfo, $listBibl}
};

declare function msParts:add-part-designation-to-recordHist($recordHist as node(), $biblId as xs:string) as node() {
  let $sourceTextBeforeBibl := $recordHist/tei:source/node()[1]
  let $sourceTextAfterBibl := $recordHist/tei:source/node()[3]
  let $sourceBibl := $recordHist/tei:source/tei:bibl
  let $sourceRef := $sourceBibl/tei:ref
  let $newSourceRef := functx:update-attributes($sourceRef,  QName("", "target"), "#"||$biblId)
  let $newSourceBibl := element {fn:node-name($sourceBibl)} {$newSourceRef}
  let $newSource := element {fn:node-name($recordHist/tei:source)} {$sourceTextBeforeBibl, $newSourceBibl, $sourceTextAfterBibl}
  return element {fn:node-name($recordHist)} {$newSource}
};

(: ------------------------------ :)
(: Updating taxonomy in textClass :)
(: ------------------------------ :)

declare function msParts:create-merged-textClass($msPartsDocumentSequence as node()+) as node() {
  
};
(:
  - textClass create a function that merges the two (or make a 'create-taxonomy' function in mss that takes string and optional part to create it, and then pass it the decoder results for 'normal' creation; here you pass the existing taxonomy values)

 - textClass/keywords[@scheme="#Wright-Bl-Taxonomy"]/list needs items for each file with the ref as-is but with an additional ref with target to the associated msPart.
:)

(: -------------------- :)
(: Merging revisionDesc :)
(: -------------------- :)

(: - revisionDesc (script that merges; need to work out ordering, etc.)
 - revisionDesc should come through with the associated msPart URI added (like the merge places and persons scripts do for duplicate URIs) to indicate which URIs each tei:change is associated with (including planned changes as this is important for later stages). Also add a tei:change for the merge itself. 
:)