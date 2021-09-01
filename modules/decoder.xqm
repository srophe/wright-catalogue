xquery version "3.0";

(:
: Module Name: Wright Decoder
: Module Version: 0.1
: Copyright: GNU General Public License v3.0
: Proprietary XQuery Extensions Used: None
: XQuery Specification: 08 April 2014
: Module Overview: This module processes Wright Decoder and Taxonomy table
:                  information for use in the Syriac Manuscript Catalog project
:)

module namespace decoder="http://srophe.org/srophe/decoder";

import module namespace config="http://srophe.org/srophe/config" at "config.xqm";

declare variable $decoder:wright-decoder :=
  let $path-to-decoder := $config:path-to-repo||"/resources/wright-decoder-simple.csv"
  let $options := map {"header": true(), "separator": "tab"}
  return csv:doc($path-to-decoder, $options);
  
declare variable $decoder:wright-taxonomy-table :=
  let $path-to-taxonomy-table := $config:path-to-repo||"/resources/wright-taxonomy-table.csv"
  let $options := map {"header": true(), "separator": "tab"}
  return csv:doc($path-to-taxonomy-table, $options);