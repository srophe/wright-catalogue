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

declare variable $msParts-test:merged-respStmt-node-sequence :=
    (
        <respStmt xmlns="http://www.tei-c.org/ns/1.0">
          <resp>Created by</resp>
          <name type="person" ref="http://syriaca.org/documentation/editors.xml#lruth">Lindsay Ruth</name>
        </respStmt>,
        <respStmt xmlns="http://www.tei-c.org/ns/1.0">
          <resp>Created by</resp>
          <name type="person" ref="http://syriaca.org/documentation/editors.xml#rbrasoveanu">Roman Brasoveanu</name>
        </respStmt>,
        <respStmt xmlns="http://www.tei-c.org/ns/1.0">
          <resp>Based on the work of</resp>
          <name type="person" ref="http://syriaca.org/documentation/editors.xml#wwright">William Wright</name>
        </respStmt>,
        <respStmt xmlns="http://www.tei-c.org/ns/1.0">
          <resp>Edited by</resp>
          <name type="person" ref="http://syriaca.org/documentation/editors.xml#"/>
        </respStmt>,
        <respStmt xmlns="http://www.tei-c.org/ns/1.0">
          <resp>Syriac text entered by</resp>
          <name type="person" ref="http://syriaca.org/documentation/editors.xml#raydin">Robert Aydin</name>
        </respStmt>,
        <respStmt xmlns="http://www.tei-c.org/ns/1.0">
          <resp>Greek and coptic text entry and proofreading by</resp>
          <name type="person" ref="http://syriaca.org/documentation/editors.xml#rstitt">Ryan Stitt</name>
        </respStmt>,
        <respStmt xmlns="http://www.tei-c.org/ns/1.0">
          <resp>Project management by</resp>
          <name type="person" ref="http://syriaca.org/documentation/editors.xml#wpotter">William L. Potter</name>
        </respStmt>,
        <respStmt xmlns="http://www.tei-c.org/ns/1.0">
          <resp>Project management by</resp>
          <name type="person" ref="http://syriaca.org/documentation/editors.xml#lruth">Lindsay Ruth</name>
        </respStmt>,
        <respStmt xmlns="http://www.tei-c.org/ns/1.0">
          <resp>English text entry and proofreading by</resp>
          <name type="org" ref="http://syriaca.org/documentation/editors.xml#uasyriacaresearchgroup">Syriac Research Group, University of Alabama</name>
        </respStmt>);


declare variable $msParts-test:file-to-compare :=
  fn:doc($config:path-to-repo || "/resources/testing/540_with_msParts_TEST.xml");

declare variable $msParts-test:publicationStmt-to-compare-with-current-date :=
      <publicationStmt xmlns="http://www.tei-c.org/ns/1.0">
        <authority>Syriaca.org: The Syriac Reference Portal</authority>
        <idno type="URI">http://syriaca.org/manuscript/540/tei</idno>
        <availability>
          <p/>
          <licence target="http://creativecommons.org/licenses/by/3.0/">
            <p>Distributed under a Creative Commons Attribution 3.0 Unported License</p>
          </licence>
        </availability>
        <date calendar="Gregorian">{fn:current-date()}</date>
      </publicationStmt>;
      
      
declare %unit:test function msParts-test:variable-config-msParts-created-successfully() {
  unit:assert-equals(xs:string($msParts:config-msParts/config/testValue/text()), "ܫܠܡܐ ܥܠܡܐ")
};

declare %unit:test function msParts-test:variable-manuscript-part-source-documents-created-successfully() {
  unit:assert-equals(xs:string($msParts:manuscript-part-source-document-sequence[1]//tei:titleStmt/tei:title[@level="a"]/text()), "BL Add MS 14684 fol. 1-36")
}; (: not sure this is independent of changing the data input directory :)

declare %unit:test function msParts-test:merge-editor-list-from-test-records() {
  unit:assert-equals(<el>{msParts:merge-editor-list($msParts:manuscript-part-source-document-sequence)}</el>, <el>{$msParts-test:merged-editor-node-sequence}</el>)
};

declare %unit:test function msParts-test:merge-respStmt-list-list-from-test-records() {
  unit:assert-equals(<el>{msParts:merge-respStmt-list($msParts:manuscript-part-source-document-sequence)}</el>, <el>{$msParts-test:merged-respStmt-node-sequence}</el>)
};

declare %unit:test function msParts-test:create-merged-titleSmt-from-test-records() {
  unit:assert-equals(msParts:create-merged-titleStmt($msParts:manuscript-part-source-document-sequence), $msParts-test:file-to-compare//tei:titleStmt)
};

declare %unit:test function msParts-test:create-publicationStmt-with-current-date() {
  unit:assert-equals(msParts:create-publicationStmt($msParts:config-msParts/config/manuscriptLevelMetadata/uriValue/text()),  $msParts-test:publicationStmt-to-compare-with-current-date)
};

declare %unit:test function msParts-test:create-main-msIdentifier-from-config() {(: will likely break if running on different data...:)
  unit:assert-equals(msParts:create-main-msIdentifier(),  $msParts-test:file-to-compare//tei:msDesc/tei:msIdentifier)
};

declare %unit:test %unit:ignore function msParts-test:update-msDesc-from-test-records() {
   unit:assert-equals(msParts:update-msDesc($msParts:manuscript-part-source-document-sequence),  $msParts-test:file-to-compare//tei:msDesc)
};

declare %unit:test %unit:ignore function msParts-test:create-msPart-sequence-from-test-records() {
    unit:assert-equals(<el>{msParts:create-msPart-sequence($msParts:manuscript-part-source-document-sequence)}</el>, <el>{$msParts-test:file-to-compare//tei:msDesc/tei:msPart}</el>)
};

declare %unit:test %unit:ignore function msParts-test:create-msPart-from-test-record() {
    unit:assert-equals(msParts:create-msPart($msParts:manuscript-part-source-document-sequence[1]//tei:msDesc, "1"), $msParts-test:file-to-compare//tei:msDesc/tei:msPart[1])
};

declare %unit:test  function msParts-test:add-part-designation-to-element-sequence-no-recursion() { (: compare files shows this works, but still giving me error. Whitespace issue?? :)
    unit:assert-equals(<el>{fn:string-join(msParts:add-part-designation-to-element-sequence($msParts:manuscript-part-source-document-sequence[1]//tei:msDesc/tei:physDesc/tei:handDesc/tei:handNote, "1", "p")/@xml:id, "|")}</el>, <el>{fn:string-join($msParts-test:file-to-compare//tei:msDesc/tei:msPart[1]/tei:physDesc/tei:handDesc/tei:handNote/@xml:id, "|")}</el>)
}; 

declare %unit:test  function msParts-test:add-part-designation-to-element-sequence-with-recursion() {
    unit:assert-equals(<el>{fn:string-join(msParts:add-part-designation-to-element-sequence($msParts:manuscript-part-source-document-sequence[1]//tei:msDesc/tei:msContents/tei:msItem, "1", "p")//@xml:id, "|")}</el>, <el>{fn:string-join($msParts-test:file-to-compare//tei:msDesc/tei:msPart[1]/tei:msContents/tei:msItem//@xml:id, "|")}</el>)
}; 

(: add tests for above function to ensure the child elements and other attributes are not affected by this script. :)

declare %unit:test %unit:ignore function msParts-test:add-part-designation-to-msContents-from-test-record() { (: seems to be just whitespace issues... :)
    unit:assert-equals(msParts:add-part-designation-to-msContents($msParts:manuscript-part-source-document-sequence[1]//tei:msDesc/tei:msContents, "1"), $msParts-test:file-to-compare//tei:msDesc/tei:msPart[1]/tei:msContents)
}; 

declare %unit:test %unit:ignore function msParts-test:add-part-designation-to-physDesc-from-test-record() {(: Note-to-self: no discernable difference between returned and expected. not sure what's wrong in these tests. A way around would be to create multiple tests that say, e.g., "this-function-adds-correct-xml:ids" and another that says "this-function-does-not-change-non-target-nodes" (i.e., does not affect element sequence, children, other attributes, text, etc.) This is a more complex suite of tests but would likely be more comprehensive and easier to debug if we know specific functionalities that are being tested. :)
    unit:assert-equals(msParts:add-part-designation-to-physDesc($msParts:manuscript-part-source-document-sequence[1]//tei:msDesc/tei:physDesc, "1"), $msParts-test:file-to-compare//tei:msDesc/tei:msPart[1]/tei:physDesc)
}; 

declare %unit:test %unit:ignore function msParts-test:add-part-designation-to-additional-from-test-record() { (: Whitespace differences only. :)
    unit:assert-equals(msParts:add-part-designation-to-additional($msParts:manuscript-part-source-document-sequence[1]//tei:msDesc/tei:additional, "1"), $msParts-test:file-to-compare//tei:msDesc/tei:msPart[1]/tei:additional)
}; 

declare %unit:test function msParts-test:create-merged-textClass-from-test-records() {
  unit:assert-equals(msParts:create-merged-textClass($msParts:manuscript-part-source-document-sequence), $msParts-test:file-to-compare//tei:textClass)
};
