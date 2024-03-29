xquery version "3.0";

(:
: Module Name: Syriaca.org Manuscript Parts Merging
: Module Version: 1.2
: Copyright: GNU General Public License v3.0
: Proprietary XQuery Extensions Used: None
: XQuery Specification: 08 April 2014
: Module Overview: This module contains functions and variable declarations
:                  used to merge TEI XML files describing manuscript parts
:                  into a single TEI XML file with nested tei:msPart elements
:)

(:~ 
: @author William L. Potter
: @version 1.2
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
  
declare variable $msParts:composite-file-template :=
  if($msParts:config-msParts/config/compositeMsFile/text() != "") then
  let $pathToFile := $msParts:path-to-msParts-folder || $msParts:config-msParts/config/compositeMsFile/text()
  return doc($pathToFile)
  else();
  
declare variable $msParts:manuscript-part-source-document-sequence :=
  for $part in $msParts:config-msParts/config/msPartFiles//part (: look at all descendant parts :)
    let $fullFilePath := $msParts:path-to-msParts-folder || $part/fileName/text()
    let $record := doc($fullFilePath)
    return if($part/oldPartId/text()) then (: if there is a part ID designation, only return that part. Otherwise return the whole file :)
      $record//tei:msPart[@xml:id = $part/oldPartId/text()]
    else $record;
     
declare variable $msParts:taxonomy-classification-map :=
    for $part in $msParts:parts-outline-map/descendant-or-self::part
    return
      <map>
        <part>{"#" || $part/newPartId/text()}</part>
        <value>{$part/taxonomyString/text()}</value>
      </map>;
     
declare variable $msParts:record-title :=
  $msParts:config-msParts/config/manuscriptLevelMetadata/recordTitle/text();
   
declare variable $msParts:ms-level-shelfmark :=
  $msParts:config-msParts/config/manuscriptLevelMetadata/shelfMark/text();
  
declare variable $msParts:ms-level-uri :=
  let $msLevelId := $msParts:config-msParts/config/manuscriptLevelMetadata/uriValue/text()
  return $config:uri-base || $msLevelId;

declare variable $msParts:file-or-console :=
  $msParts:config-msParts/config/fileOrConsole/text();
  
declare variable $msParts:output-directory :=
  $config:path-to-repo || $msParts:config-msParts/config/outputFileDirectory/text();
  
declare variable $msParts:output-file-name :=
  let $msId := functx:substring-after-if-contains($msParts:ms-level-uri, $config:uri-base)
  return $msParts:output-directory || $msId || ".xml";
  
declare variable $msParts:index-of-pending-id-updates-directory :=
  $config:path-to-repo || $config:index-of-pending-id-updates-directory;

(:
Create the outline map for use in nesting the parts correctly
:)

declare variable $msParts:parts-outline-map :=
  msParts:create-parts-outline-map($msParts:config-msParts//msPartFiles/part, "");
  
  
declare function msParts:create-parts-outline-map($configMap as node()+, $idPrefix as xs:string)
as node()*
  {
    for $part at $i in $configMap
    let $record := doc($msParts:path-to-msParts-folder || $part/fileName/text())
    let $desc := if($part/oldPartId/text()) then $record//tei:msPart[@xml:id = $part/oldPartId/text()] else $record//tei:msDesc
    let $uri := $desc/tei:msIdentifier/tei:idno/text()
    
    let $wrightTaxonomyNode := $record//tei:profileDesc/tei:textClass/tei:keywords[@scheme="#Wright-BL-Taxonomy"]
    
    (: If the $desc is part of a record with multiple msParts, get the ref/@target corresponding to that part; otherwise get the ref/@target :)
    let $taxonomyCatRef := 
      if($part/oldPartId/text()) then $wrightTaxonomyNode//tei:item[tei:ref/@target = "#"||$part/oldPartId/text()]/tei:ref[@target != "#"||$part/oldPartId/text()]/@target
      else $wrightTaxonomyNode//tei:item/tei:ref/@target
    let $taxonomyCatRef := string($taxonomyCatRef)
    
    let $newPartId := if($idPrefix = "") then "Part"||$i else $idPrefix||"_"||$i
    
    let $subParts := if($part/part) then msParts:create-parts-outline-map($part/part, $newPartId) else()
    return
    <part>
      {
        $part/fileName,
        $part/oldPartId
      }
      <uri>{$uri}</uri>
      <taxonomyString>{$taxonomyCatRef}</taxonomyString>
      <newPartId>{$newPartId}</newPartId>
      {
        $subParts
      }
    </part>
  };
(: -------------------------------------------------------- :)
(: Create document node of full record from component parts :)
(: -------------------------------------------------------- :)

declare function msParts:create-composite-document($msPartsDocumentSequence as node()+) as item()+ {
  (: the first record in the msParts sequence serves as the template for all data shared between msPart records :)
  let $templateDocument := if(boolean($msParts:composite-file-template)) then $msParts:composite-file-template else $msPartsDocumentSequence[1]

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
  
  (: the update-msDesc function also returns an index of updated xml:id values. This is then passed from this function to the caller :)
  let $temp := msParts:update-msDesc($msPartsDocumentSequence)
  let $msDesc := $temp[1]
  let $index := $temp[2]
  
  (: make the top-level part of the index a record element :)
  let $index := <record>{$index/@*, $index/*}</record>
  let $textClass := msParts:create-merged-textClass()
  let $revisionDesc := msParts:create-merged-revisionDesc($msPartsDocumentSequence)
  
  (: build out document from components :)
  let $sourceDesc := element {QName("http://www.tei-c.org/ns/1.0", "sourceDesc")} {$msDesc}
  
  let $fileDesc := element {QName("http://www.tei-c.org/ns/1.0", "fileDesc")} {$titleStmt, $editionStmt, $publicationStmt, $sourceDesc}
  let $profileDesc := element {QName("http://www.tei-c.org/ns/1.0", "profileDesc")} {$langUsage, $textClass}
  
  let $teiHeader := element {QName("http://www.tei-c.org/ns/1.0", "teiHeader")} {$fileDesc, $encodingDesc, $profileDesc, $revisionDesc}
  
  let $documentNode := element {QName("http://www.tei-c.org/ns/1.0", "TEI")} {attribute {"xml:lang"} {"en"}, $teiHeader, $facsimile, $textElement}
  
  (: return document node based on built components :)
  return (document {$processingInstructions, $documentNode}, $index)
  
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
    return if($respStmt/tei:resp/text() = "Created by") then element {node-name($respStmt)} {$respStmt/*} else ()
  let $editorRespStmts := for $respStmt in $fullRespStmtList
    return if($respStmt/tei:resp/text() = "Edited by") then element {node-name($respStmt)} {$respStmt/*} else ()
  let $projectManagerRespStmts := for $respStmt in $fullRespStmtList
    return if($respStmt/tei:resp/text() = "Project management by") then element {node-name($respStmt)} {$respStmt/*} else ()
  
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
  (: use the declared template file, if it exists. Otherwise use the first file in the ms part file sequence :)
  let $templateDoc := if(boolean($msParts:composite-file-template)) then $msParts:composite-file-template else $documentSequence[1]
  let $titleStmtTemplate := $templateDoc//tei:titleStmt
  let $recordTitle := $titleStmtTemplate/tei:title[@level="a"]
  let $recordTitle := element {node-name($recordTitle)} {$recordTitle/@*, $msParts:record-title}
  let $moduleTitle := $titleStmtTemplate/tei:title[@level="m"]
  let $mergedEditorList := msParts:merge-editor-list(($templateDoc, $documentSequence))
  let $mergedRespStmtList := msParts:merge-respStmt-list(($templateDoc, $documentSequence))
  
  (: Create the updated titleStmt element from the new record title, all the elements shared between the records, and the element and respStmt lists :)
  return element {node-name($titleStmtTemplate)} {$recordTitle, $moduleTitle, $titleStmtTemplate/*[not(name() = "title") and not(name() = "editor") and not(name() = "respStmt")], $mergedEditorList, $mergedRespStmtList}
};

declare function msParts:create-publicationStmt($uri as xs:string) as node() {
  let $uri := if (fn:starts-with($uri, "http")) then $uri||"/tei" else $config:uri-base||$uri||"/tei"
  
  let $templateRecord := if(boolean($msParts:composite-file-template)) then $msParts:composite-file-template else $msParts:manuscript-part-source-document-sequence[1]
  let $templatePubStmt := $templateRecord//tei:publicationStmt
  let $idno := $templatePubStmt/tei:idno
  let $idno := element {fn:node-name($idno)} {$idno/@*, $uri}
  let $publicationDate := element {QName("http://www.tei-c.org/ns/1.0", "date")} {attribute {"calendar"} {"Gregorian"}, fn:current-date()}
  return element {fn:node-name($templatePubStmt)} {$templatePubStmt/tei:authority, $idno, $templatePubStmt/tei:availability, $publicationDate}
};

(: -------------------------------------------- :)
(: Updating manuscript description with msParts :)
(: -------------------------------------------- :)

declare function msParts:update-msDesc($msPartDocumentSequence as node()+) as item()+ {
  let $msDescId := "manuscript-"||$msParts:config-msParts/config/manuscriptLevelMetadata/uriValue/text()
  let $msIdentifier := msParts:create-main-msIdentifier()
  
  (: this function properly nests the msParts components based on the $msParts:parts-outline-map node :)
  let $msPartSeq := msParts:compose-msParts-outline($msPartDocumentSequence, $msParts:parts-outline-map)
  
  (: nest the msParts within a containing msDesc element using manuscript-level msIdentifier information :)
  let $msDesc := element {QName("http://www.tei-c.org/ns/1.0", "msDesc")} {attribute {"xml:id"} {$msDescId}, $msIdentifier, $msPartSeq} 
  
  (: return the msDesc after running it through the id update process. This function also returns the update index :)
  return mss:update-msDesc-xml-id-values($msDesc, true (), "")
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

(:~ 
: Creates a sequence of msPart elements, nested as required from a linear sequence of msPart elements.
: Nesting occurs based on the outline specified in config-msParts.xml
: this outline in turn is used to create the $msPartsOutlineMap which
: has the form:
: <container>
:  <part>
:   <fileName>From config-msParts.xml</fileName>
:   <oldPartId>From config-msParts.xml; optional</oldPartId>
:   <uri>of the msPart, used to match with the document sequence</uri>
:   <taxonomyString>Gotten from the document and used to create the taxonomy item</taxonomyString>
:   <newPartId>Based on location in outline</newPartId>
:  </part>
: </container>
: Parts can be nested in any way that is required.
:)
declare function msParts:compose-msParts-outline($msPartDocumentSequence as node()+, $msPartsOutlineMap as node()+) 
as node()+
{
  for $part in $msPartsOutlineMap
  let $desc := 
    for $doc in $msPartDocumentSequence
    where $doc/descendant-or-self::*[name() = "msPart" or name() = "msDesc"]/tei:msIdentifier/tei:idno/text() = $part/uri/text() (: where the URI of the document matches that in the outline map :)
    return if(name($doc) = "msPart") then $doc else $doc//tei:msDesc
  let $subParts := if($part/part) then msParts:compose-msParts-outline($msPartDocumentSequence, $part/part) else()
  return element {QName("http://www.tei-c.org/ns/1.0", "msPart")} {$desc/*, $subParts}
};

(:~ 
: @deprecated as of 1.2 and replaced with msParts:compose-msParts-outline and mss:update-msDesc-xml-id-values :)
declare function msParts:create-msPart-sequence($msPartDocumentSequence as node()+) as node()+ {
  (: the function msParts:create-msPart returns both an msPart element and a <part/> element containing an index of id updates. These get separated out below :)
  let $msPartsAndIndex := 
    for $doc at $i in $msPartDocumentSequence 
    (: use the tei:msDesc node if the ms part is a separate file; otherwise use the root node which should be a tei:msPart gotten from the template file :)
    let $desc := if($doc//tei:msDesc) then $doc//tei:msDesc else $doc
    return msParts:create-msPart($desc, fn:string($i))
  
  (: separate the msPart nodes from the nodes containing id update indices. :)
  let $partsIndices := $msPartsAndIndex/self::*:part
  let $msParts := $msPartsAndIndex/self::tei:msPart
  
  
  (: create a record-level index of id updates containing indices for each msPart :)
  let $index := <record uri="{$msParts:ms-level-uri}">{$partsIndices}</record>
  return (<container>{$msParts}</container>, $index)
};

(:~ 
: @deprecated as of 1.2 replaced with mss:update-msDesc-xml-id-values :)
declare function msParts:create-msPart($singleMsDesc as node(), $partNumber as xs:string) as item()+ {
  
  (: update the xml:ids of the descendants using the part designation as prefix. :) 
  let $temp := mss:update-msDesc-xml-id-values($singleMsDesc, false (), "p" || $partNumber)
  let $newMsDesc := $temp[1]
  
  (: Build the index of updates for this msPart, storing the <update/> elements in a <part/> element whose @uri attribute is the URI for that msPart (in its tei:msIdentifier/tei:idno). These will then be nested within each <record/> element identified by the overall composite ms. :)
  let $index := $temp[position() > 1]
  let $partIndex := <part uri="{$singleMsDesc/tei:msIdentifier/tei:idno/text()}">{$index}</part>
  
  (: Separately add the part designation to the tei:bibls in the tei:additional node :)
  let $additional := msParts:add-part-designation-to-additional($singleMsDesc/tei:additional, $partNumber)
  
  let $msPartNode := element {QName("http://www.tei-c.org/ns/1.0", "msPart")} {attribute {"xml:id"} {"Part"||$partNumber}, attribute {"n"} {$partNumber}, $newMsDesc/*[not(name() = "additional")], $additional}
  
  (: return both the msPart node and the :)
  return ($msPartNode, $partIndex)
  
  
  (:
  DEPRECATED as of 1.1
  
  let $msIdentifier := $singleMsDesc/tei:msIdentifier
  let $msContents := msParts:add-part-designation-to-msContents($singleMsDesc/tei:msContents, $partNumber)
  let $physDesc := msParts:add-part-designation-to-physDesc($singleMsDesc/tei:physDesc, $partNumber)
  let $history := $singleMsDesc/tei:history
  let $additional := msParts:add-part-designation-to-additional($singleMsDesc/tei:additional, $partNumber)
  return element {QName("http://www.tei-c.org/ns/1.0", "msPart")} {attribute {"xml:id"} {"Part"||$partNumber}, attribute {"n"} {$partNumber}, $msIdentifier, $msContents, $physDesc, $history, $additional}
  :)
};

(:~
: @deprecated as of 1.1 and replaced with mss:update-msDesc-xml-id-values
:)
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

(:~
: @deprecated as of 1.1 and replaced with mss:update-msDesc-xml-id-values
:)
declare function msParts:add-part-designation-to-msContents($msContents as node(), $partNumber as xs:string) as node() {
  let $msItems := msParts:add-part-designation-to-element-sequence($msContents/tei:msItem, $partNumber, "p")
  return element {fn:node-name($msContents)} {$msContents/*[not(name()='msItem')], $msItems}
};

(:~
: @deprecated as of 1.1 and replaced with mss:update-msDesc-xml-id-values
:)
declare function msParts:add-part-designation-to-physDesc($physDesc as node(), $partNumber as xs:string) as node() {
    let $objectDesc := $physDesc/tei:objectDesc
    let $handDesc := $physDesc/tei:handDesc
    let $handDesc := element {fn:node-name($handDesc)} {$handDesc/@*, msParts:add-part-designation-to-element-sequence($handDesc/tei:handNote, $partNumber, "p")}
    let $decoDesc := if($physDesc/tei:decoDesc) then element {fn:node-name($physDesc/tei:decoDesc)} {$physDesc/tei:decoDesc/@*, msParts:add-part-designation-to-element-sequence($physDesc/tei:decoDesc/tei:decoNote, $partNumber, "p")} else()
    let $additions := if($physDesc/tei:additions/tei:list/tei:item) then msParts:add-part-designation-to-additions-items($physDesc/tei:additions, $partNumber)
      else element {QName("http://www.tei-c.org/ns/1.0", "additions")} {}
    let $bindingDesc := $physDesc/tei:bindingDesc (: as-is :)
    let $sealDesc := $physDesc/tei:sealDesc (: as-is :)
    let $accMat := $physDesc/tei:accMat
    return element {QName("http://www.tei-c.org/ns/1.0", "physDesc")} {$objectDesc, $handDesc, $decoDesc, $additions, $bindingDesc, $sealDesc, $accMat}
};

(:~
: @deprecated as of 1.1 and replaced with mss:update-msDesc-xml-id-values
:)
declare function msParts:add-part-designation-to-additions-items($additions as node(), $partNumber as xs:string) as node() {
  let $additionsList := element {fn:node-name($additions/tei:list)} {msParts:add-part-designation-to-element-sequence($additions/tei:list/tei:item, $partNumber, "p")}
  return element {fn:node-name($additions)} {$additions/*[not(name()= name($additionsList))], $additionsList}
};

declare function msParts:add-part-designation-to-additional($additional as node(), $partNumber as xs:string) as node() {
  let $wrightBibl := $additional/tei:listBibl/tei:bibl
  let $newBiblId := "Wrightpart"||$partNumber
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
  return element {fn:node-name($recordHist)} {$newSource, $recordHist/*[not(name() = "source")]}
};

(: ------------------------------ :)
(: Updating taxonomy in textClass :)
(: ------------------------------ :)

declare function msParts:create-merged-textClass() as node() {
  let $valueSeq := $msParts:taxonomy-classification-map//value
  let $partSeq := $msParts:taxonomy-classification-map//part
  let $keywords := mss:create-keywords-node("Wright-BL-Taxonomy", $valueSeq, $partSeq)
  return element {QName("http://www.tei-c.org/ns/1.0", "textClass")} {$keywords}
};

(: -------------------- :)
(: Merging revisionDesc :)
(: -------------------- :)

declare function msParts:create-merged-revisionDesc($msPartsDocumentSequence as node()+) as node() {
  let $docUriSeq := for $doc in $msPartsDocumentSequence
    return if($doc//tei:msDesc) then $doc//tei:msDesc/tei:msIdentifier/tei:idno/text() else $doc/tei:msIdentifier/tei:idno/text()
  let $mergedChangeLog := "Merged the following URIs as msPart elements: "||fn:string-join($docUriSeq, "; ")
  let $mergedChangeNode := element {QName("http://www.tei-c.org/ns/1.0", "change")} {attribute {"who"} {$config:editors-document-uri||"#"||$config:change-log-script-id}, attribute {"when"} {fn:current-date()}, $mergedChangeLog}
  let $fullChangeListByUri := for $doc in ($msParts:composite-file-template, $msPartsDocumentSequence)
    let $docUri := $doc//tei:msDesc/tei:msIdentifier/tei:idno/text()
    let $changeLogPrefix := "["||$docUri||"]: "
    for $change in $doc//tei:revisionDesc/tei:change
      let $newChangeLog := ($changeLogPrefix, $change/node())
      return element {QName("http://www.tei-c.org/ns/1.0", "change")} {$change/@*, $newChangeLog}
      
  let $plannedChangeListOrderedByUri := for $change in $fullChangeListByUri
    return if($change[@type="planned"]) then $change else ()
    
  let $completedChangeListOrderedByDate := for $change in $fullChangeListByUri
    where $change[not(@type = "planned")]
    order by $change/@when descending
    return $change
  
  return element {QName("http://www.tei-c.org/ns/1.0", "revisionDesc")} {attribute {"status"} {"draft"}, $mergedChangeNode, $completedChangeListOrderedByDate, $plannedChangeListOrderedByUri}
};