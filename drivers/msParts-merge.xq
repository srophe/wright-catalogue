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


declare default element namespace "http://www.tei-c.org/ns/1.0";

declare option output:omit-xml-declaration "no";
declare option file:omit-xml-declaration "no";


let $nothing := file:create-dir($msParts:output-directory)
(:
need:
- if file-or-console = "file" store it
:)
let $outputDoc := msParts:create-composite-document($msParts:manuscript-part-source-document-sequence)
return if($msParts:file-or-console = "file") then
          file:write($msParts:output-file-name, $outputDoc)
       else 
         $outputDoc
   