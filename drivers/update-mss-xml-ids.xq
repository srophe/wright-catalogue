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



let $inputDoc := doc("C:\Users\anoni\Documents\GitHub\srophe\wright-catalogue\data\5_finalized\ms-parts\249\250.xml")
return mss:update-xml-id-values($inputDoc, false ())
(: return functx:remove-attributes-deep($inputDoc//msContents/msItem, "xml:id") :)
  
  (:
  an option
  
  1. go through and call the function for each input record
  2. the function returns a two-item sequence: ($newRecord as document(), $updateIndex as item())
  3. create a (sub-)collection of just the new records (either filtering the sequence by item type or using position() and if it's even or odd) (the former is more reliable but might be tricky to implement)
  4. create a (sub-)collection of just the update index items (using the opp as #3)
  5. create the full update index from the collection of xml stubs
  6. for record in updated collection, overwrite the input record. (the input doc URI should be the same as $inputCollectionUri || $docId (numerical portion of the URI) || ".xml")
    - for each returns the functions put($updateDoc, $outputDocPath (as created above)) and file:write($pathToIndexStorage, $updateIndex). Note that the update-index will always be the same file and, somewhat inefficiently, will overwrite itself. I can't think of a way around this as file:append in a for loop would just append to the empty file due to the pending update list issue.
      - now, one issue to worry about would be overwriting existing index updates. I think the solution is to add the date (and time to ensure no overlap) to the index file name. Then, on the other side of things you can have the propagate-updates script collate any file with "update-index_yyy-mm-dd_hh-mm-ss", or something similar, into a single input index for processing.
      
To-do

1. make the function that runs the updates on each file (this is likely an addition to the mss.xqm module. it should handle the various item types; the msParts; etc. and should return an updated ms record and an entry (even if empty) for any updates to push through data)
2. write the loop for creating the sequence of updated records and snippets of the index
3. write the method of separating out the updated records from index snippets
4. write the method of collating the index (here filter empty entries?)
  - also decide on how to name the index
5. write the method of looping through and storing the updated record and the index
6. once this is all working, write the script that propagates updates
  :)