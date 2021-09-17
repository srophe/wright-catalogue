xquery version "3.0";

(:
: Module Name: Manuscript Catalogue Post Processing Driver
: Module Version: 1.0
: Copyright: GNU General Public License v3.0
: Proprietary XQuery Extensions Used: None
: XQuery Specification: 08 April 2014
: Module Overview: This main module runs a set of manuscript stub records through
:                  processing to add project metadata and enumerations
:)

import module namespace functx="http://www.functx.com";
import module namespace config="http://srophe.org/srophe/config" at "../modules/config.xqm";
import module namespace mss="http://srophe.org/srophe/mss" at "../modules/mss.xqm";

declare namespace tei = "http://www.tei-c.org/ns/1.0";


let $inputCollectionPath := $config:path-to-repo || $config:config/config/inputDirectory/text()
let $inputCollection := fn:collection($inputCollectionPath)

let $outputDirectory := $config:path-to-repo || $config:config/config/outputDirectory/text()

(: create a list of files to ignore based on a list of ignored directories. this and the check if record exists should go in their own module (even in the mss module) :)
let $urisToIgnore := for $coll in $config:config/config/ignoredDirectoryList/directory/text()
  (: need to handle if not actually pointing to the wright-catalogue path...But that's system dependent since you can't know if it's the C: drive or not :)
  for $doc in fn:collection($config:path-to-repo || $coll)
    let $docId := functx:substring-after-if-contains(mss:get-record-uri($doc), $config:uri-base)
    return $docId
    (: return fn:substring-before($fileName, ".xml") :)
let $urisToIgnore := fn:distinct-values($urisToIgnore)

for $doc in $inputCollection
  let $docId :=  functx:substring-after-if-contains($doc//tei:sourceDesc/tei:msDesc/tei:msIdentifier/tei:idno[@type="URI"]/text(), $config:uri-base)
  let $outputFileUri := $outputDirectory || $docId || ".xml"
  let $recordExists := for $uri in $urisToIgnore
    where $uri = $docId
    return "true"
  (: let $updatedRecord := mss:create-updated-document($doc) :)
  return if ($docId != "" and not($recordExists = "true")) then  fn:put(mss:create-updated-document($doc), $outputFileUri)

(:
part of ignored directories:

    
  let $docPath := fn:document-uri($doc)
  let $fileName := fn:substring-after($docPath, $inputDirectory)
  let $docId := $doc//msDesc/msIdentifier/idno[@type="URI"]/text()
  let $docUri := if(fn:starts-with($docId, "http://syriaca.org/manuscript/")) then $docId else fn:concat("http://syriaca.org/manuscript/", $docId)
  return if ($docId != '' and not($recordExists)) then (DO ALL THE UPDATES)
:)


