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
declare namespace err = "http://www.w3.org/2005/xqt-errors";


let $inputCollectionPath := $config:path-to-repo || $config:config/config/inputDirectory/text()
let $inputCollection := fn:collection($inputCollectionPath)

let $outputDirectory := $config:path-to-repo || $config:config/config/outputDirectory/text()
let $nothing := file:create-dir($outputDirectory) (: create the output directory if it doesn't exist :)

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
    
  let $updatedRecord := if ($docId != "") then try {
    mss:create-updated-document($doc)
  } catch err:XPTY0004  {
    <error>
    <recId>{$docId}</recId>
    <errorData>
      <code>{$err:code}</code>
      <description>{$err:description}</description>
      <value>{$err:value}</value>
      <module>{$err:module}</module>
      <lineNumber>{$err:line-number}</lineNumber>
      <columnNumber>{$err:column-number}</columnNumber>
      <additional>{$err:additional}</additional>
      </errorData>
    </error>
  }
  
  return if ($docId != "" and not($recordExists = "true")) then  fn:put($updatedRecord, $outputFileUri)


