xquery version "3.0";

(:
: Module Name: Update Syriaca.org Manuscript xml:ids
: Module Version: 1.0
: Copyright: GNU General Public License v3.0
: Proprietary XQuery Extensions Used: None
: XQuery Specification: 08 April 2014
: Module Overview: This main module updates the xml:id values of various TEI
:                  elements in Syriaca.org manuscript records. These updates
:                  should be written back to disk. An index of id changes is
:                  also created by this module. It can be used by a separate
:                  module to propagate ID updates to other data which may
:                  refer to a now-deprecated ID value.
:)

(:~ 
: @author William L. Potter
: @version 1.0
:)

import module namespace msParts="http://srophe.org/srophe/msParts" at "../modules/msParts.xqm";
import module namespace mss="http://srophe.org/srophe/mss" at "../modules/mss.xqm";
import module namespace functx="http://www.functx.com";

declare default element namespace "http://www.tei-c.org/ns/1.0";

declare variable $local:input-collection :=
  collection("/home/arren/Documents/GitHub/britishLibrary-data/data/tei/");


for $doc in $local:input-collection
(: let $hasMsPart := if($inputDoc//msPart) then true () else false () :)
return try {
  put(mss:update-document-xml-id-values($doc)[1], document-uri($doc))
 (: mss:update-document-xml-id-values($doc)[position() > 1] :) 
}
catch* {
      let $error := 
    <error>
      <traceback>
        <code>{$err:code}</code>
        <description>{$err:description}</description>
        <value>{$err:value}</value>
        <module>{$err:module}</module>
        <location>{$err:line-number||":"||$err:column-number}</location>
        <additional>{$err:additional}</additional>
      </traceback>
      <msUri>{$doc//msDesc/msIdentifier/idno[@type="URI"]/text()}</msUri>
      <numberOfParts>{count($doc//msPart)}</numberOfParts>
    </error>
    return update:output($error)
}
 