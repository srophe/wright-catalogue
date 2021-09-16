xquery version "3.0";

(:
: Module Name: Unit Testing for Syriaca.org Manuscript Cataloguing
: Module Version: 1.0
: Copyright: GNU General Public License v3.0
: Proprietary XQuery Extensions Used: None
: XQuery Specification: 08 April 2014
: Module Overview: This module contains unit tests for developing the
                   Syriaca.org manuscript module.
:)

module namespace mss-test="http://srophe.org/srophe/mss/mss-test";

import module namespace mss="http://srophe.org/srophe/mss" at "mss.xqm";
import module namespace config="http://srophe.org/srophe/config" at "config.xqm";
import module namespace stack="http://wlpotter.github.io/ns/stack" at "https://raw.githubusercontent.com/wlpotter/xquery-utility-modules/main/stack.xqm";

declare namespace tei = "http://www.tei-c.org/ns/1.0";

declare variable $mss-test:file-to-test := 
  let $path-to-file := $config:path-to-repo||"/resources/testing/317_testable.xml"
  return fn:doc($path-to-file);
  
declare variable $mss-test:file-to-compare :=
  let $path-to-file := $config:path-to-repo||"/resources/testing/317_full.xml"
  return fn:doc($path-to-file);

declare variable $mss-test:current-date-publicationStmt-to-compare :=
  let $publicationStmtToCompare := $mss-test:file-to-compare//tei:publicationStmt
  let $dateElement := element {QName("http://www.tei-c.org/ns/1.0", "date")} {attribute {"calendar"} {"Gregorian"}, fn:current-date()}
  return element {QName("http://www.tei-c.org/ns/1.0", "publicationStmt")} {$publicationStmtToCompare/*[not(self::tei:date)], $dateElement};

declare variable $mss-test:current-date-revisionDesc-to-compare :=
  let $revisionDescToCompare := $mss-test:file-to-compare//tei:revisionDesc
  let $currentDate := fn:current-date()
  let $currentDate := fn:substring(xs:string($currentDate), 1, 10)
  let $changeElement := element {QName("http://www.tei-c.org/ns/1.0", "change")} {attribute {"who"} {$config:editors-document-uri||"#"||$config:change-log-script-id}, attribute {"when"} {$currentDate}, $config:change-log-message}
  return element {QName("http://www.tei-c.org/ns/1.0", "revisionDesc")} {$revisionDescToCompare/@*, $changeElement, $revisionDescToCompare/*[position() > 1]};

declare variable $mss-test:linear-element-sequence :=
  (<el type="a"/>, <el type="el"/>, <el type="b"><content/>text</el>, <el type="el"/>);
  
declare variable $mss-test:initial-msItem-up-stack := 
  stack:initialize(());
  
declare variable $mss-test:initial-msItem-down-stack :=
  stack:initialize(("a1", "b1", "c1", "d1", "e1", "f1", "g1", "h1", "i1", "j1", "k1", "l1", "m1", "n1"));
  
declare %unit:before function mss-test:setup() {
  (: make current date correct ?? this is stupidly complex...:)

};

declare %unit:after function mss-test:teardown() {
  $config:path-to-repo||"/resources/testing/317_full.xml"
};

declare %unit:test function mss-test:create-processing-instructions-from-config() {
  unit:assert-equals(mss:create-processing-instructions(), $mss-test:file-to-compare/processing-instruction())
};

(: whitespace irregularities and no auto-gen of dates; otherwise the same :)
declare %unit:test %unit:ignore function mss-test:create-document-with-processing-instructions() {
  unit:assert-equals(mss:create-document($mss-test:file-to-test), $mss-test:file-to-compare)
};

(: whitespace issue only :)
declare %unit:test %unit:ignore function mss-test:update-full-record-from-stub() {
  unit:assert-equals(mss:update-full-record($mss-test:file-to-test), $mss-test:file-to-compare/*[not(self::processing-instruction())])
};

declare %unit:test function mss-test:create-teiHeader() {
  unit:assert-equals(mss:update-teiHeader($mss-test:file-to-test)/teiHeader, $mss-test:file-to-compare/teiHeader)
};
(: test whether the teiHeader of the processed file is the same as the hand-done file; should fail for a while 
SKIPPING UNTIL READY TO TEST
:)

declare %unit:test function mss-test:create-record-title() {
   unit:assert-equals(mss:create-record-title($mss-test:file-to-test), $mss-test:file-to-compare//tei:titleStmt/tei:title[@level="a"])
};

declare %unit:test function mss-test:get-shelf-mark-from-stub() {
  unit:assert-equals(mss:get-shelf-mark($mss-test:file-to-test), "Add. 14,581")
};

declare %unit:test function mss-test:clean-shelf-mark-preamble-no-follia-range() {
  unit:assert-equals(mss:clean-shelf-mark("Add. 14,581"), "BL Add MS 14581")
};

declare %unit:test function mss-test:clean-shelf-mark-preamble-follia-range() {
  unit:assert-equals(mss:clean-shelf-mark("Add. 14,581, foll. 1-31"), "BL Add MS 14581, foll. 1-31")
};

declare %unit:test function mss-test:get-editor-name-from-uri-first-last-name() {
  unit:assert-equals(mss:get-editor-name-from-uri("lruth"), "Lindsay Ruth")
};

declare %unit:test function mss-test:get-editor-name-from-uri-first-middle-last-name() {
  unit:assert-equals(mss:get-editor-name-from-uri("wpotter"), "William L. Potter")
};

declare %unit:test function mss-test:get-editor-name-from-uri-title-first-last-name() {
  unit:assert-equals(mss:get-editor-name-from-uri("rakhrass"), "Dayroyo Roger-Youssef Akhrass")
};

declare %unit:test function mss-test:create-editor-element-general-editor() {
  unit:assert-equals(mss:create-editor-element("dmichelson", "general-editor"), $mss-test:file-to-compare//tei:titleStmt/tei:editor[1])
};

declare %unit:test function mss-test:create-resp-stmt-created-by() {
  unit:assert-equals(mss:create-resp-stmt("jpagan", "Created by"), $mss-test:file-to-compare//tei:titleStmt/tei:respStmt[1])
};

declare %unit:test function mss-test:update-titleStmt-from-stub() {
  unit:assert-equals(mss:update-titleStmt($mss-test:file-to-test), $mss-test:file-to-compare//tei:titleStmt)
};

declare %unit:test function mss-test:update-publicationStmt-from-stub-with-current-date() {
  
  unit:assert-equals(mss:update-publicationStmt($mss-test:file-to-test), $mss-test:current-date-publicationStmt-to-compare)
};

declare %unit:test function mss-test:get-record-uri-from-number-only() {
  unit:assert-equals(mss:get-record-uri($mss-test:file-to-test), "http://syriaca.org/manuscript/317")
};

declare %unit:test function mss-test:get-record-uri-from-full-uri() {
  unit:assert-equals(mss:get-record-uri($mss-test:file-to-compare), "http://syriaca.org/manuscript/317")
};

(: sourceDesc tests :)

(: whitespace differences only :)
declare %unit:test %unit:ignore function mss-test:update-sourceDesc-from-stub() {
  unit:assert-equals(mss:update-sourceDesc($mss-test:file-to-test), $mss-test:file-to-compare//tei:sourceDesc)
};

(: whitespace differences only :)
declare %unit:test %unit:ignore function mss-test:update-msDesc-from-stub() {
  unit:assert-equals(mss:update-msDesc($mss-test:file-to-test), $mss-test:file-to-compare//tei:msDesc)
};

declare %unit:test function mss-test:update-msIdentifier-from-stub() {
  unit:assert-equals(mss:update-msIdentifier($mss-test:file-to-test), $mss-test:file-to-compare//tei:msIdentifier)
};

declare %unit:test function mss-test:create-altIdentifier-elements-from-stub() {
  unit:assert-equals(<el>{mss:create-altIdentifier-elements($config:project-config/config//tei:msIdentifier/tei:altIdentifier, "317")}</el>, <el>{$mss-test:file-to-compare//tei:msIdentifier/tei:altIdentifier}</el>)
};

declare %unit:test function mss-test:create-bl-shelfmark-element-from-stub() {
  unit:assert-equals(<el>{mss:create-bl-shelfmark-element("317")}</el>, <el>{$mss-test:file-to-compare//tei:msIdentifier/tei:altIdentifier[tei:idno[@type="BL-Shelfmark"]]/*}</el>)
};

declare %unit:test function mss-test:create-wright-bl-arabic-element-from-stub() {
  unit:assert-equals(<el>{mss:create-wright-bl-arabic-element("317")}</el>, <el>{$mss-test:file-to-compare//tei:msIdentifier/tei:altIdentifier[tei:idno[@type="Wright-BL-Arabic"]]/*}</el>)
};

declare %unit:test function mss-test:create-wright-bl-roman-element-from-stub() {
  unit:assert-equals(<el>{mss:create-wright-bl-roman-element("317")}</el>, <el>{$mss-test:file-to-compare//tei:msIdentifier/tei:altIdentifier[tei:idno[@type="Wright-BL-Roman"]]/*}</el>)
};

declare %unit:test function mss-test:update-msContents-from-stub() {
  unit:assert-equals(mss:update-msContents($mss-test:file-to-test//tei:msContents), $mss-test:file-to-compare//tei:msContents)
};

declare %unit:test function mss-test:add-msItem-id-and-enumeration-values-from-stub() {
  unit:assert-equals(mss:add-msItem-id-and-enumeration-values($mss-test:file-to-test//tei:msContents, $mss-test:initial-msItem-up-stack, $mss-test:initial-msItem-down-stack, 1)[1], <msItemContainer>{$mss-test:file-to-compare//tei:msContents/tei:msItem}</msItemContainer>)
};

declare %unit:test function mss-test:update-physDesc-from-stub() {
  unit:assert-equals(mss:update-physDesc($mss-test:file-to-test//tei:physDesc), $mss-test:file-to-compare//tei:physDesc)
};

declare %unit:test function mss-test:update-handDesc-from-stub() {
  unit:assert-equals(mss:update-handDesc($mss-test:file-to-test//tei:handDesc), $mss-test:file-to-compare//tei:handDesc)
};

declare %unit:test function mss-test:update-handNote-sequence-from-stub() {
  unit:assert-equals(mss:update-handNote-sequence($mss-test:file-to-test//tei:handDesc/tei:handNote), $mss-test:file-to-compare//tei:handDesc/tei:handNote)
};

declare %unit:test function mss-test:update-additions-from-stub() {
  unit:assert-equals(mss:update-additions($mss-test:file-to-test//tei:additions), $mss-test:file-to-compare//tei:additions)
};

declare %unit:test %unit:ignore function mss-test:enumerate-element-sequence-simple-linear() {
  (: still figuring out how to test this...:)
  unit:assert-equals(<result>{string(mss:enumerate-element-sequence($mss-test:linear-element-sequence, "", boolean(1))/@n)}</result>, <result>{(1, 2, 3, 4)}</result>)
};

declare %unit:test %unit:ignore function mss-test:update-ms-history-from-stub() {
  unit:assert-equals(mss:update-ms-history($mss-test:file-to-test//tei:history), $mss-test:file-to-compare//tei:history)
}; (: might just copy from config file  unless I want to process any dates? :)

declare %unit:test %unit:ignore function mss-test:update-ms-additional-uri-exists() { (:I don't understand...these are the same file but not showing up as such...:)
  unit:assert-equals(mss:update-ms-additional("317"), $mss-test:file-to-compare//tei:additional)
};

declare %unit:test function mss-test:create-page-citedRange-element-uri-exists() {
  unit:assert-equals(mss:create-page-citedRange-element( "317"), $mss-test:file-to-compare//tei:additional/tei:listBibl/tei:bibl/tei:citedRange[@unit="pp"])
};

(: profileDesc tests :)

declare %unit:test function mss-test:update-profileDesc-from-stub() {
  unit:assert-equals(mss:update-profileDesc($mss-test:file-to-test), $mss-test:file-to-compare//tei:profileDesc)
};

declare %unit:test function mss-test:create-textClass-from-stub() {
  unit:assert-equals(mss:create-textClass("http://syriaca.org/manuscript/317"), $mss-test:file-to-compare//tei:textClass)
};

declare %unit:test function mss-test:create-wright-taxonomy-node() {
  unit:assert-equals(mss:create-wright-taxonomy-node("317"), $mss-test:file-to-compare//tei:textClass/tei:keywords/tei:list)
};

declare %unit:test function mss-test:create-keywords-node-wright-bl-taxonomy-with-hashtag() {
  unit:assert-equals(mss:create-keywords-node("317", "#Wright-BL-Taxonomy"), $mss-test:file-to-compare//tei:textClass/tei:keywords)
};

(: revisionDesc tests :)

declare %unit:test function mss-test:update-revisionDesc-from-stub() {
  unit:assert-equals(mss:update-revisionDesc($mss-test:file-to-test//tei:revisionDesc), $mss-test:current-date-revisionDesc-to-compare)
};

declare %unit:test function mss-test:update-tei-text-elements-from-stub() {
  unit:assert-equals(mss:update-tei-text-elements($mss-test:file-to-test), <nonHeaderElements>{$mss-test:file-to-compare/tei:TEI/*[not(self::tei:teiHeader)]}</nonHeaderElements>)
};