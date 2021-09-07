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
  
(: taxonomy table lookup functions :)

declare function decoder:get-wright-taxonomy-record-from-wright-arabic-numeral($recWrightArabicNumeral as xs:string) as node()? {
  let $taxonomyRecord := for $record in $decoder:wright-taxonomy-table/csv/record
    where xs:integer($recWrightArabicNumeral) ge xs:integer($record/wrightArabicNumeral/text())
                    and xs:integer($recWrightArabicNumeral) lt xs:integer($record/following-sibling::*[1]/wrightArabicNumeral/text())
    return $record
 return $taxonomyRecord
};

declare function decoder:get-wright-taxonomy-id-from-uri($recId as xs:string) as xs:string? {
  let $recWrightArabicNumeral := decoder:get-wright-arabic-numeral-from-uri($recId)
  let $taxonomyRecord := decoder:get-wright-taxonomy-record-from-wright-arabic-numeral($recWrightArabicNumeral)
  return $taxonomyRecord/idValue/text()
  
};

(: Decoder lookup functions :)

declare function decoder:get-wright-decoder-record-from-uri($recId as xs:string) as node()? {
  let $wrightDecoderRecord := for $record in $decoder:wright-decoder/csv/record
    where $recId = $record/uri/text()
    return $record
  return $wrightDecoderRecord
};

declare function decoder:get-wright-arabic-numeral-from-uri($recId as xs:string) as xs:string? {
  let $wrightDecoderRecord := decoder:get-wright-decoder-record-from-uri($recId)
  return $wrightDecoderRecord/wrightArabicNumeral/text()
};

declare function decoder:get-wright-roman-numeral-from-uri($recId as xs:string) as xs:string? {
  let $wrightDecoderRecord := decoder:get-wright-decoder-record-from-uri($recId)
  return $wrightDecoderRecord/wrightRomanNumeral/text()
};

declare function decoder:get-bl-shelfmark-from-uri($recId as xs:string) as xs:string? {
  let $wrightDecoderRecord := decoder:get-wright-decoder-record-from-uri($recId)
  return $wrightDecoderRecord/shelfmark/text()
};
