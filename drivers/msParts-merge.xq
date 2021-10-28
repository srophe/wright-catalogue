xquery version "3.0";

(:
: Module Name: Syriaca.org Manuscript Parts Merging Driver
: Module Version: 1.0
: Copyright: GNU General Public License v3.0
: Proprietary XQuery Extensions Used: None
: XQuery Specification: 08 April 2014
: Module Overview: This main module merges TEI manuscript catalogue records
:                  that represent manuscript parts into a composite manuscript
:                  record with mulitple tei:msPart elements
:)

(:~ 
: @author William L. Potter
: @version 1.0
:)

import module namespace msParts="http://srophe.org/srophe/msParts" at "../modules/msParts.xqm";
import module namespace functx="http://www.functx.com";


declare default element namespace "http://www.tei-c.org/ns/1.0";

declare option output:omit-xml-declaration "no";
declare option file:omit-xml-declaration "no";


let $nothing := if($msParts:file-or-console = "file") then 
    (file:create-dir($msParts:output-directory), 
     file:create-dir($msParts:index-of-pending-id-updates-directory))

let $temp := msParts:create-composite-document($msParts:manuscript-part-source-document-sequence)
let $outputDoc := $temp[1]
let $index := $temp[2]
let $index := <index xmlns="">{$index}</index>

(: construct the file name for the index out of the current date and time in the form 2021-10-28T14_44_30_547 :)
let $currentDateTime := string(current-dateTime())
let $currentDateTime := functx:substring-before-last($currentDateTime, "-")
let $currentDateTime := replace($currentDateTime, ":|\.", "_")
let $indexFileName := $msParts:index-of-pending-id-updates-directory || "index_" || $currentDateTime || ".xml"
return if($msParts:file-or-console = "file") then
          (file:write($msParts:output-file-name, $outputDoc, map {'method': 'xml', 'omit-xml-declaration': 'no'}),
           file:write($indexFileName, $index, map {'method': 'xml', 'omit-xml-declaration': 'no'}))
       else 
         ($outputDoc, $index)
   