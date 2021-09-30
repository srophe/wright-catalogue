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
    
    
(:
- build fileDesc consists of:
  - titleStmt (already made)
  - editionStmt (from template)
  - publicationStmt (made) --> call with $msParts:config-msParts/config/manuscriptLevelMetadata/uriValue/text(). This function could be moved to mss and refactored so the mss update function calls it with the found URI
  - sourceDesc (the main functionality is here)
- encodingDesc comes from template
- profileDesc
  - langUsage from template
  - textClass create a function that merges the two (wait on the one taxonomy issue??) (or make a 'create-taxonomy' function in mss that takes string and optional part to create it, and then pass it the decoder results for 'normal' creation; here you pass the existing taxonomy values)
- revisionDesc (script that merges; need to work out ordering, etc.)
- text element, for now, comes from template. If we were ever to have text of fasc we would need to merge and order properly. but not worth doing right now.
  
:)
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
  (:
  msContents -- update with p\d+
  physDesc > handDesc and (and decoDesc) additions update with p\d+
  history as is
  additional add Part\d+ to adminInfo/source/ref/@target and lisBibl/bilb/@xml:id
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
    (:
    - update xml:id of $el
    - return $el/@* (except xml:id which is now the updated one)
    - if $el has children of  the same node-name, run this function on those children.
    - return the children that are the same node-name as is, and the updated children of the same name (this only applies to msItems as there are no nested handDesc, etc.)
    :)
};

declare function msParts:add-part-designation-to-msContents($msContents as node(), $partNumber as xs:string) as node() {
  let $change-this := ""
  let $msItems := msParts:add-part-designation-to-element-sequence($msContents/tei:msItem, $partNumber, "p")
  return $msContents
  (:
  go through each msItem and add "p||$parNumber" to the existing xml:id. 
  go through an sub-msItems
  I Think we could do this more generically?
  :)
};

declare function msParts:add-part-designation-to-physDesc($physDesc as node(), $partNumber as xs:string) as node() {
  let $change-this := ""
  return $physDesc
};

declare function msParts:add-part-designation-to-additional($additional as node(), $partNumber as xs:string) as node() {
  let $change-this := ""
  return $additional
};
(:
To-do
- functions needed
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