xquery version "3.0";

(:
: Module Name: Syriaca.org Manuscript Cataloguing Configuration
: Module Version: 0.1
: Copyright: GNU General Public License v3.0
: Proprietary XQuery Extensions Used: None
: XQuery Specification: 08 April 2014
: Module Overview: This module configures the repository context for the Syriaca
:                  manuscript module
:)

module namespace config="http://srophe.org/srophe/config";

import module namespace functx="http://www.functx.com";

declare namespace tei = "http://www.tei-c.org/ns/1.0";

declare variable $config:path-to-repo := 
   let $rawPath := "C:\Users\anoni\Documents\GitHub\srophe\wright-catalogue"
   return
     replace($rawPath, "\\", "/");

declare variable $config:config :=
   let $pathToModuleConfig := $config:path-to-repo||"/parameters/config.xml"
   return
     doc($pathToModuleConfig);

declare variable $config:project-config :=
   let $pathToProjConfig := $config:path-to-repo||"/parameters/config-proj.xml"
   return
     doc($pathToProjConfig);
     
declare variable $config:uri-base := $config:project-config/config/projectMetadata/uriBase/text();

declare variable $config:editors-document-uri := 
    $config:project-config/config/projectMetadata/editorsFileUri/text();
    
declare variable $config:editors-document := 
    let $pathToEditorsDoc := $config:path-to-repo||"/resources/editors.xml"
    return fn:doc($pathToEditorsDoc); (: currently assuming this will be a TEI file like Syriaca's, need to enforce this or handle other options? :)

(:
global variables:


- set editor for running scripts? (this should go in the main module??)
- file input directory from config (maybe a main module thing?)
- file output info from config (e.g. is it writeback or not; if not give a location for where to put file outputs -- this is maybe a main module thing?)
- you'll want a function for tokenizing the decoder, etc. so should have variables for that here
- ignored directories? or is this just in main?

:)