xquery version "3.0";

(:
: Module Name: Unit Testing for Syriaca.org Manuscript Parts Merging
: Module Version: 1.0
: Copyright: GNU General Public License v3.0
: Proprietary XQuery Extensions Used: None
: XQuery Specification: 08 April 2014
: Module Overview: This module contains unit tests for developing the
                   Syriaca.org manuscript parts module.
:)

module namespace msParts-test="http://srophe.org/srophe/mss/msParts-test";

import module namespace msParts="http://srophe.org/srophe/msParts" at "msParts.xqm";
import module namespace mss="http://srophe.org/srophe/mss" at "mss.xqm";
import module namespace config="http://srophe.org/srophe/config" at "config.xqm";

declare namespace tei = "http://www.tei-c.org/ns/1.0";


declare variable $msParts-test:merged-editor-node-sequence :=
    (<editor xmlns="http://www.tei-c.org/ns/1.0" role="general-editor" ref="http://syriaca.org/documentation/editors.xml#dmichelson">David A. Michelson</editor>,
    <editor xmlns="http://www.tei-c.org/ns/1.0" role="creator" ref="http://syriaca.org/documentation/editors.xml#wwright">William Wright</editor>,
    <editor xmlns="http://www.tei-c.org/ns/1.0" role="creator" ref="http://syriaca.org/documentation/editors.xml#dmichelson">David A. Michelson</editor>,
    <editor xmlns="http://www.tei-c.org/ns/1.0" role="creator" ref="http://syriaca.org/documentation/editors.xml#raydin">Robert Aydin</editor>,
    <editor xmlns="http://www.tei-c.org/ns/1.0" role="creator" ref="http://syriaca.org/documentation/editors.xml#lruth">Lindsay Ruth</editor>,
    <editor xmlns="http://www.tei-c.org/ns/1.0" role="creator" ref="http://syriaca.org/documentation/editors.xml#rbrasoveanu">Roman Brasoveanu</editor>);

declare %unit:test function msParts-test:variable-config-msParts-created-successfully() {
  unit:assert-equals(xs:string($msParts:config-msParts/config/testValue/text()), "ܫܠܡܐ ܥܠܡܐ")
};

declare %unit:test function msParts-test:variable-manuscript-part-source-documents-created-successfully() {
  unit:assert-equals(xs:string($msParts:manuscript-part-source-document-sequence[1]//tei:titleStmt/tei:title[@level="a"]/text()), "BL Add MS 14684 fol. 1-36")
}; (: not sure this is independent of changing the data input directory :)

declare %unit:test function msParts-test:merge-editor-creator-list() {
  unit:assert-equals(<el>{msParts:merge-editor-list($msParts:manuscript-part-source-document-sequence)}</el>, <el>{$msParts-test:merged-editor-node-sequence}</el>)
};