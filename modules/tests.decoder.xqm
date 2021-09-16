xquery version "3.0";

(:
: Module Name: Unit Testing for Syriaca.org Manuscript Cataloguing
: Module Version: 1.0
: Copyright: GNU General Public License v3.0
: Proprietary XQuery Extensions Used: None
: XQuery Specification: 08 April 2014
: Module Overview: This module contains unit tests for developing the
                   Syriaca.org decoder module.
:)

module namespace decoder-test="http://srophe.org/srophe/mss/mss-test";

import module namespace decoder="http://srophe.org/srophe/decoder" at "decoder.xqm";
import module namespace config="http://srophe.org/srophe/config" at "config.xqm";

declare namespace tei = "http://www.tei-c.org/ns/1.0";

declare variable $decoder-test:file-to-test := 
  let $path-to-file := $config:path-to-repo||"/resources/testing/317_testable.xml"
  return fn:doc($path-to-file);
  
declare variable $decoder-test:file-to-compare :=
  let $path-to-file := $config:path-to-repo||"/resources/testing/317_full.xml"
  return fn:doc($path-to-file);
  
declare %unit:before function decoder-test:setup() {
  (: make current date correct ?? this is stupidly complex...:)

};

declare %unit:after function decoder-test:teardown() {
};

declare %unit:test function decoder-test:get-wright-taxonomy-record-from-wright-arabic-numeral-within-range() {
  unit:assert-equals(decoder:get-wright-taxonomy-record-from-wright-arabic-numeral("70")//idValue/text(), text {"bible-nt"})
};

declare %unit:test function decoder-test:get-wright-taxonomy-record-from-wright-arabic-numeral-equals-lowest() {
  unit:assert-equals(decoder:get-wright-taxonomy-record-from-wright-arabic-numeral("161")//idValue/text(), text {"bible-punctuation"})
};

declare %unit:test function decoder-test:get-wright-taxonomy-record-from-wright-arabic-numeral-equals-highest() {
  unit:assert-equals(decoder:get-wright-taxonomy-record-from-wright-arabic-numeral("526")//idValue/text(), text {"funerals"})
};

declare %unit:test function decoder-test:get-wright-taxonomy-record-from-wright-arabic-numeral-out-of-bounds-high() {
  unit:assert-equals(decoder:get-wright-taxonomy-record-from-wright-arabic-numeral("10000")//idValue/text(), ())
};

declare %unit:test function decoder-test:get-wright-decoder-record-from-uri-exists() {
  unit:assert-equals(decoder:get-wright-decoder-record-from-uri("8")/shelfmark/text(), text {"Add. 12,136"})
};

declare %unit:test function decoder-test:get-wright-decoder-record-from-uri-does-not-exist() {
  unit:assert-equals(decoder:get-wright-decoder-record-from-uri("0")/shelfmark/text(), ())
};

declare %unit:test function decoder-test:get-wright-arabic-numeral-from-uri-exists() {
  unit:assert-equals(decoder:get-wright-arabic-numeral-from-uri("2"), "9")
};

declare %unit:test function decoder-test:get-wright-arabic-numeral-from-uri-no-associated-numeral() {
  unit:assert-equals(decoder:get-wright-arabic-numeral-from-uri("1"), ())
};

declare %unit:test function decoder-test:get-wright-arabic-numeral-from-uri-does-not-exisst() {
  unit:assert-equals(decoder:get-wright-arabic-numeral-from-uri("0"), ())
};

declare %unit:test function decoder-test:get-wright-taxonomy-id-from-uri-exists() {
  unit:assert-equals(decoder:get-wright-taxonomy-id-from-uri("192"), "funerals")
};