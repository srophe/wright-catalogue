# Structure of the data file:

We have compiled all the data into one html file and then customized it as an xml document. The document is a hybrid with some elements borrowed from html and some from TEI. It does not have a schema since it is just a customization.

Currently the data has three types of elements:

The following elements should be preserved in the final version of the file:
- Element doc occurs 1 time. (This is the root element)
- Element msDesc occurs 510 times. (Child of the root node, each msDesc contains information about a single manuscript.)
- Element msIdentifier occurs 1020 times. (Child of msDesc. Each msDesc should have two msIdentifier elements which serve as unique ids for that manuscript. These elements and their contents will remain as is in the final version).
- Element msItem occurs 9154 times. (These need to be transformed to nest inside each other. Every msItem must be the child of either a msDesc or another msItem)
- Element physDesc occurs 510 times. (Child of msDesc. These elements and their contents will remain as is in the final version.)

In addition the following elements will be added in the parsing:
- Element idno
- Element title
- Element locus
- Element rubric
- Element note 

The following element will need transformation in some cases:
- Element span occurs 12712 times with a couple of different uses marked by attributes.

The following elements (from html text styling) should be removed/ignored, but the contents of their text nodes should be kept:
- Element br occurs 3 times.
- Element del occurs 1 time.
- Element em occurs 7174 times.
- Element img occurs 1 times.
- Element li occurs 9 times.
- Element ol occurs 8 times.
- Element strong occurs 634 times.
- Element sub occurs 14 times.
- Element sup occurs 827 times.



# Deliverables:

Each msDesc element represents a distinct group of data. We would like you to perform a data transformation on the msItem children elements in the msDesc.

We are requesting two primary deliverables:

1.  Nest the msItem elements so that they conform to the implied hierarchy in the prose original.

2.  Tokenize and parsing of the contents of the msItem elements into child elements based on patterns.

## Deliverable 1: Nested Hierarchy

### Use of Document Order to Identify msItem Elements for Nesting
The document order of the msItem elements is significant for this deliverable. We want the transformation to evaluate and nest only those msItem elements which occur as following siblings of the physDesc element. The transformation should not be applied to any of the msItem elements which precede the physDesc element.

### Hierarchy Pattern

In the original printed document, the information which is now wrapped in msItem elements was organized in an outline indicated by the following textual pattern:

```
I. First Level
1. Second Level
a. Third Level
α. Fourth Level
```
The nesting relationship of the hierarchy can be determined by the level identifier used:

Level one is marked with a Roman Numeral (I., II., III., IV., etc.).

Level two is marked with an Indo-Arabic Numeral (1., 2., 3., 4., etc.).

Level three is marked by a lower-case Latin letter (a., b., c., d., etc.).

- Note: The pattern for level three repeats after "z." which is followed by "aa.", "bb.", "cc." etc. See line 12944.

Level four is marked with a lower-case Greek letter (α., β., γ., etc.) from the Unicode Range: 0370–03FF.

- Note: Sometimes the OCR has not recognized these Greek characters correctly and instead sometimes rendered the ``α`` (alpha) character {U+03B1} incorrectly as the lower-case Latin letter ``a`` {U+0061}.
- Note: The pattern for level four repeats after "ω." which is followed by "αα.", "ββ.", "γγ." etc. See line 12495.

In most cases the msItem text node will begin with one of the following regex patterns:

Level One: ``\s*[MDCLXVI]+\.\s*``

Level Two: ``\s*\d+\.\s*``

Level Three: ``\s*[a-z]+\.\s*``

Level Four: ``\s*[α-ω]+\.\s*``

Due to inaccuracy in the OCR sometimes the whitespaces, punctuation and even identifier may vary.

Sometimes, there is no level identifier present at the front of the msItem
in these cases we would like the transformation to assign the msItem to the same branch level as its immediate preceding sibling msItem. In order to mark these for later editorial correction, these msItems should be assigned an identifier marked with ``~`` (U+007E) + the appropriate kind level identifier. Examples: ``"~I.", "~1.", "~a.", "~α."`` (These identifiers do not need to be serial, they can repeat ``"~I.", "~I.",`` etc.)

Sometimes first msItem to be transformed is marked with an Indo-Arabic Numerals, eg. ``1.``. In these cases the tree structure of the nested msItem elements will skip the use of Roman Numerals and will have up to three levels of branches Arabic Numeral/Latin letter/Greek letter. (See note above, by "first msItem to transformed" we mean the first msItem that is a following sibling of the physDesc element.) See line 12908 for an example.

Sometimes the first msItem that is a following sibling of the physDesc element (or several of the first msItems) will not have any level identifier. In these cases, the transformation should always mark the the level identifier using a ``~`` (U+007E) + the Roman Numeral I level identifier: ``"~I."`` See line 13432 for an example of such a case.

### Example of Nesting Transformation

Raw Data:
```
<msDesc xml:id="Add.21-210.">
    <msItem>First Round Proofing done by Nathan Godwin. Completed 2/25/11. (Syriac: 227)</msItem>
    <msIdentifier><strong>DCCCXLI.</strong></msIdentifier>
    <physDesc>Paper, about 10 in. by 6 7/8, consisting of 232 leaves, some of which are much stained and torn, especially foll. 1, 121, 122, 151, 155, 178, 202, 203, and 232; whilst others have been retouched and repaired by more modern hands. The quires, signed with letters, are 23 in number, but the last is im­perfect. There are from 21 to 35 lines in each page. This manuscript, which seems to be written by three hands, is dated A. Gr. 1553, A.D. 1242. It contains—</physDesc>
    <msItem>1. The Festal Homilies of Moses bar #Kipha, or #Mar Severus, with some other discourses by the same writer. Title: $<span dir="rtl">ܥܠ ܣܒܪܐ ܠܐ ܡܒܗܬܢܐ ܕܬܠܝܬܝܘܬܐ ܏ܩܕ ܟܬܒ̇ܝܢܢ ܟܬܒܐ ܕܬܘܪ̈ܓܡܐ ܕܥܒܝܕܝܢ ܠܡܘܫܐ ܒܪܟܐܦܐ</span>. A short history of the author is inserted at fol. 54 a, with the title: $<span dir="rtl">ܩܦܠܐܘܢ ܕܡܚܲܘܐ ܫܪܒܗ ܘܬܫܥܝܬܗ ܕܡܘܫܐ ܒܪ ܟܐܦܐ ܕܡܢ ܐܝܟܐ ܐܝܬܘܗܝ ܗܘܐ.</span>. It has been printed by Assemani in the Bibl. Or., t. ii., p. 218, note.</msItem>
    <msItem><em>a.</em>On the Annunciation of Zacharias, $<span dir="rtl">ܕܥܠ ܣܘܒܪܗ ܕܙܟܪܝܐ</span>. Fol. 1 b.</msItem>
    ...
```

After Nesting of msItems Using Identifiers
```
<msDesc xml:id="Add.21-210.">
    <msItem>First Round Proofing done by Nathan Godwin. Completed 2/25/11. (Syriac: 227)</msItem>
    <msIdentifier><strong>DCCCXLI.</strong></msIdentifier>
    <physDesc>Paper, about 10 in. by 6 7/8, consisting of 232 leaves, some of which are much stained and torn, especially foll. 1, 121, 122, 151, 155, 178, 202, 203, and 232; whilst others have been retouched and repaired by more modern hands. The quires, signed with letters, are 23 in number, but the last is im­perfect. There are from 21 to 35 lines in each page. This manuscript, which seems to be written by three hands, is dated A. Gr. 1553, A.D. 1242. It contains—</physDesc>
    <msItem>1. The Festal Homilies of Moses bar #Kipha, or #Mar Severus, with some other discourses by the same writer. Title: $<span dir="rtl">ܥܠ ܣܒܪܐ ܠܐ ܡܒܗܬܢܐ ܕܬܠܝܬܝܘܬܐ ܏ܩܕ ܟܬܒ̇ܝܢܢ ܟܬܒܐ ܕܬܘܪ̈ܓܡܐ ܕܥܒܝܕܝܢ ܠܡܘܫܐ ܒܪܟܐܦܐ</span>. A short history of the author is inserted at fol. 54 a, with the title: $<span dir="rtl">ܩܦܠܐܘܢ ܕܡܚܲܘܐ ܫܪܒܗ ܘܬܫܥܝܬܗ ܕܡܘܫܐ ܒܪ ܟܐܦܐ ܕܡܢ ܐܝܟܐ ܐܝܬܘܗܝ ܗܘܐ.</span>. It has been printed by Assemani in the Bibl. Or., t. ii., p. 218, note.
      <msItem><em>a.</em>On the Annunciation of Zacharias, $<span dir="rtl">ܕܥܠ ܣܘܒܪܗ ܕܙܟܪܝܐ</span>. Fol. 1 b.</msItem>
    </msItem>
    ...
```

## Deliverable 2: Tokenization and Parsing of msItem Contents
We would like the proof of concept script to identify five tokens inside the msItem. These items will not be found in every msItem and their order is slightly variable. They are listed here in what we expect will be the most likely document order of occurrence.

### `<idno>`: Level Identifier
This token will either be the first token in the msItem or it will be absent in which case it should be constructed and inserted. It can be identified or constructed using the outline pattern described above. It should be marked up inside `<idno>`. See the notes above for some of the variance in whitespaces and punctuation.

Examples:

Raw:
``
<msItem>1. The Consecration of the Church,<span dir="rtl">ܛܟܣ̣ܐ ܩ̈ܠܐــ .ܡ̇ܢ ܩܕܡܝܐ ܕܥܠ ܩܘܕܫ ܥܕܬܐ</span>, fol. 1<em>b</em>;<span dir="rtl">ܡܕܪ̈ܫܐ</span>, fol. 2<em>b</em>.</msItem>
``

Parsed with Existing Identifier:
``
<msItem>
  <idno>1.</idno>
``

Raw:
``
<physDesc>Eighteen vellum leaves, about 7 1/4 in. by 5 3/8 (Add. 14,525, foll. 28—45). The writing is good and regular, of the xth or xith cent., with from 16 to 23 lines in each page. They formed part of—</physDesc>
<msItem>A volume, containing anthems and hymns (<span dir="rtl">ܥܢܝ̈ܢܐ ܘܩ̈ܠܐ</span>) for the festivals of the whole year.</msItem>
``

Parsed with Constructed Identifier:
``
...</physDesc>
<msItem>
  <idno>~I.</idno>
``

Notes: Sometimes HTML elements may interrupt the token (such as ``<em>``), these should be stripped out of the document.

### ``<title xml:lang="en">``: English Title
If the `<idno>` is immediately followed by a string of Roman characters, then the next token is a following sibling `<title xml:lang="en">`. The usual pattern is for `<title>` to occur as the second token. It is also possible for it to be the first token in cases where there is no `<idno>`token in the raw data. Sometimes there is no `<title>` token at all. In very rare cases, the `<title>`might be the third token if it is preceded by the `<locus>` token. The beginning of the `<title>` token is any string of Roman characters at the beginning of the msItem text node (if there is no `<idno>`), or any string of Roman characters after the `<idno>` or the `<locus>` tokens. The end of the `<title>` token is the end of the string of Roman Characters marked either by the pattern for a `<locus>` token or a string of Syriac characters (Unicode block: U+0700..U+074F, but including also U+0308). In most cases a punctuation mark occurs between the `<title>` and the next token, but it is not always present and the type varies (full stop, comma, semi-colon, em-dash, etc.).

Example:

Raw:
``
<msItem>1. The Consecration of the Church,<span dir="rtl">ܛܟܣ̣ܐ ܩ̈ܠܐــ .ܡ̇ܢ ܩܕܡܝܐ ܕܥܠ ܩܘܕܫ ܥܕܬܐ</span>, fol. 1<em>b</em>;<span dir="rtl">ܡܕܪ̈ܫܐ</span>, fol. 2<em>b</em>.</msItem>
``

Parsed:
``
<msItem>
    <idno>1.</idno>
    <title xml:lang="en">The Consecration of the Church</title>
``

### `<locus>`: Folio Numbers
The expressions ``[F|f]ol[l]?\. \d+`` and ``"[F|f]ol[l]?. \d+[ ]?[a|b]?-?\d*[ ]?[a|b]?`` occur in various locations in the msItem elements.

Examples: ``fol. 138`` ``foll. 160—178`` ``foll. 160—178 a.`` ``Fol. 30<em>a</em>.`` ``fol 48b``

These regular expressions marks a `<locus>` token.

In most cases the `<locus>` will occur after the ``<title xml:lang="en">`` as a following sibling or after the `<rubric xml:lang="syr">` as a child. It is also the case that the `<locus>` will occur as a child of the `<note>` token.

Example:

Raw:
``
<msItem>2. The Commemoration of S. John the Baptist; imperfect. Fol. 31<em>a</em>.</msItem>
``

Parsed:
``
<msItem>
  <idno>2.</idno>
  <title xml:lang="en">The Commemoration of S. John the Baptist; imperfect.</title>
  <locus>Fol. 31a.</locus>
</msItem>
``

### `<rubric xml:lang="syr">`: Syriac Title
The Syriac title will always be the first string of Syriac characters (Unicode block: U+0700..U+074F, but including also U+0308) to occur in the msItem. In the raw data Syriac text blocks are currently marked by `<span dir="rtl">` html tags. If the Syriac string is tagged as `<rubric xml:lang="syr">`. this `<span dir="rtl">` should be removed. If not, the `<span dir="rtl">` should be retained.

In most cases the Syriac Title token will occur as the fourth token, a following sibling after the `<idno>`, `<title>`, and `<locus>`tokens. If any of these are missing then the Syriac Title token can occur earlier.

In some cases, the Syriac Title token will be immediately followed by the pattern for the `<locus>` token, in this case, the `<locus>` token becomes a child of `<rubric xml:lang="syr">` (it does NOT become a following sibling).

Example:

Raw:
``
<msItem>1. The Consecration of the Church,<span dir="rtl">ܛܟܣ̣ܐ ܩ̈ܠܐــ .ܡ̇ܢ ܩܕܡܝܐ ܕܥܠ ܩܘܕܫ ܥܕܬܐ</span>, fol. 1<em>b</em>;<span dir="rtl">ܡܕܪ̈ܫܐ</span>, fol. 2<em>b</em>.</msItem>
``

Parsed:
``
<msItem>
    <idno>1.</idno>
    <title xml:lang="en">The Consecration of the Church</title>
    <rubric xml:lang="syr">ܛܟܣ̣ܐ ܩ̈ܠܐــ .ܡ̇ܢ ܩܕܡܝܐ ܕܥܠ ܩܘܕܫ ܥܕܬܐ<locus>fol 1.</locus></rubric>
``

### `<note>`: Note
Any character data which cannot be tokenized or parsed should become the contents of a single `<note>`. This `<note>` should be analyzed for any child `<locus>`tokens but not for any other tokens. If there is a `<note>` token (and in many cases there may not be), it will always be the last token inside the msItem.

Example:

Raw:
``
<msItem>1. The Consecration of the Church,<span dir="rtl">ܛܟܣ̣ܐ ܩ̈ܠܐــ .ܡ̇ܢ ܩܕܡܝܐ ܕܥܠ ܩܘܕܫ ܥܕܬܐ</span>, fol. 1<em>b</em>;<span dir="rtl">ܡܕܪ̈ܫܐ</span>, fol. 2<em>b</em>.</msItem>
``

Parsed:
``
<msItem>
    <idno>1.</idno>
    <title xml:lang="en">The Consecration of the Church</title>
    <rubric xml:lang="syr">ܛܟܣ̣ܐ ܩ̈ܠܐــ .ܡ̇ܢ ܩܕܡܝܐ ܕܥܠ ܩܘܕܫ ܥܕܬܐ<locus>fol 1.</locus></rubric>
    <note>;<span dir="rtl">ܡܕܪ̈ܫܐ</span>, fol. 2<em>b</em>.</note>
</msItem>
``
