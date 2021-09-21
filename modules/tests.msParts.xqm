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

declare %unit:test function msParts-test:config-file-created-successfully() {
  unit:assert-equals(xs:string($msParts:config-msParts/config/testValue/text()), "ܫܠܡܐ ܥܠܡܐ")
};