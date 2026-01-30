Lua YAML-like Parser Module Documentation
Overview
This is a server-side Lua module for parsing a custom configuration format that resembles YAML but with specialized syntax. The parser processes text files containing elements, attributes, and comments, converting them into structured data with typed values.

Architecture
The module follows a layered architecture with clear separation of concerns:

Core Parser (lib.lua) - File reading and element collection

Element Parser (element.lua) - Line parsing and tokenization

Utilities (enums.lua, keyval.lua, trim.lua) - Supporting components

File-by-File Documentation
1. enums.lua - Constants and Type Definitions
Purpose
Defines all constants, glyph mappings, and error types used throughout the parser.

Constants:
Delimiters:

UNSET - Initial state before delimiter detection

COMMA - ',' delimiter for token separation

SPACE - ' ' delimiter for token separation

Element Types:

STANDARD - Regular elements (e.g., element key=value)

GLOBAL - Global elements prefixed with '!' (e.g., !global key=value)

COMMENT - Comment lines prefixed with '#'

ATTRIBUTE - Attribute elements prefixed with '@' (e.g., @attr=value)

Glyphs (ASCII codes):

NONE - 0 (empty)

EQUAL - 61 ('=')

AT - 64 ('@')

BANG - 33 ('!')

HASH - 35 ('#')

SPACE - 32 (' ')

COMMA - 44 (',')

QUOTE - 34 ('"')

Functions:
glyphForType(type)

Returns the corresponding prefix character for an element type

STANDARD → none, GLOBAL → '!', ATTRIBUTE → '@', COMMENT → '#'

glyphIsReserved(glyph)

Checks if a character is a reserved glyph

Used to identify special characters in parsing

Error Types:
Various error messages for parsing failures including unterminated quotes, missing identifiers, and malformed tokens.

2. trim.lua - String Utility
Purpose
Removes whitespace (characters ≤ 32) from both ends of a string.

Function:
trim(str)

Returns string with leading/trailing whitespace removed

Returns empty string if string contains only whitespace

Efficiently implemented with byte-level operations

3. keyval.lua - Key-Value Pair Object
Purpose
Simple container for key-value pairs with string representation.

Class:
KeyVal.new(key, val)

Creates a new key-value pair

Both key and value can be nil

Implements __tostring metamethod:

With key: returns "key=value"

Without key: returns just the value

4. element.lua - Core Parsing Logic
Purpose
Contains the main parsing engine for converting text lines into structured elements.

Classes:
1. Element Class

Represents a parsed element with attributes and arguments.

Properties:

attributes: Array of attribute elements (type=ATTRIBUTE)

text: Element name/identifier

args: Array of KeyVal objects

type: Element type (STANDARD, GLOBAL, etc.)

Methods:

setAttributes(attrs)

Assigns accumulated attributes to the element

Validates that all provided elements are ATTRIBUTE type

upsert(keyval)

Inserts or updates a key-value argument

Case-insensitive key matching

hasKey(key)

Checks if element has a specific key (case-insensitive)

hasKeys(keyList)

Checks if element has all keys in the list

getKeyValue(key, orValue)

Returns value for key or default value

getKeyValueAsInt(key, orValue)

Returns value rounded to nearest integer

Positive: math.floor(num + 0.5)

Negative: math.ceil(num - 0.5)

getKeyValueAsBool(key, orValue)

Returns true only if string equals "true" (case-insensitive)

getKeyValueAsNumber(key, orValue)

Returns numeric value using tonumber()

printArgs()

Returns comma-separated string representation of arguments

Metamethods:

__tostring: Returns element representation with prefix glyph

2. ElementParser Class

State machine for parsing individual lines.

Properties:

delimiter: Current delimiter (SPACE or COMMA)

element: Current Element being built

error: Any parsing error encountered

lineNumber: For error tracking

Methods:

parseTokens(input, start)

Main token parsing loop

Processes all tokens in a line

Internal Parsing Logic:

Delimiter Detection (evaluateDelimiter):

Skips quoted strings first

Determines delimiter by finding first non-quoted space or comma

Supports both space-separated and comma-separated formats

Token Evaluation (evaluateToken):

Extracts token between delimiters

Splits on '=' for key-value pairs

Adds to element's arguments

Quote Handling:

Tracks quoted regions to avoid splitting within strings

Detects unterminated quotes as errors

read(line) Function

Main entry point for parsing a single line.

Parsing Steps:

Trim line and check for empty

Identify element type from first non-space character:

# → COMMENT (entire rest of line as text)

@ → ATTRIBUTE

! → GLOBAL

Other → STANDARD

Extract element name (until first space)

Parse remaining tokens as arguments

Return parser with element or error

5. lib.lua - Main Module Interface
Purpose
Orchestrates file parsing and element collection.

Classes:
Collector Class

Manages state during file parsing.

Properties:

lineCount: Current line number (1-indexed)

pendingAttrs: Accumulated attributes waiting for an element

elements: Array of parsed elements

errors: Array of parsing errors

Methods:

handleLine(line)

Processes a single line

Increments line counter

Uses element.read() to parse line

Handles element collection logic:

ATTRIBUTE elements: accumulate in pendingAttrs

STANDARD elements: attach pending attributes, then add to collection

GLOBAL/COMMENT elements: add directly (no attribute attachment)

Errors: record with line number

Functions:
parse(path)

Main public function

Reads file line by line using io.lines()

Returns tuple: (elements, errors)

Module Exports:

parse: Main parsing function

enums: Constants module

element: Element parsing module

Input Format Specification
Element Types:
Standard Elements:

text
elementName key1=value1 key2=value2
Global Elements (prefixed with !):

text
!globalName key=value
Attributes (prefixed with @):

text
@attributeName=value
Comments (prefixed with #):

text
# This is a comment
Syntax Features:
Delimiters: Both space and comma are supported

text
element a=1 b=2     # Space-delimited
element a=1, b=2    # Comma-delimited (consistent per element)
Quoted Strings:

text
element name="John Smith" city="New York, NY"
Attribute Accumulation:

text
@attr1=value1
@attr2=value2
elementName key=value   # Gets both @attr1 and @attr2
Data Types:
Strings: Default type

Numbers: Automatically converted with tonumber()

Booleans: Only "true" (case-insensitive) evaluates to true

Integers: Numbers rounded to nearest whole integer

Usage Example
lua
local parser = require('lib')
local elements, errors = parser.parse('config.txt')

for i, elem in ipairs(elements) do
    print(elem.text)
    print("  Type:", elem.type)
    
    if elem.type == parser.enums.ElementTypes.STANDARD then
        print("  Value:", elem.getKeyValue("key"))
        print("  Numeric:", elem.getKeyValueAsNumber("count", 0))
        print("  Boolean:", elem.getKeyValueAsBool("enabled", false))
    end
end

if #errors > 0 then
    print("Errors:")
    for i, err in ipairs(errors) do
        print("  Line", err.line, ":", err.type)
    end
end
Error Handling
The parser collects errors without stopping:

Each error includes line number and type (error message)

Common errors: unterminated quotes, missing element names, malformed prefixes

Runtime errors are caught and converted to RUNTIME error type

Design Patterns
Builder Pattern: ElementParser builds Element objects incrementally

Collector Pattern: Collector accumulates elements and attributes

Strategy Pattern: Different parsing strategies for different element types

Flyweight Pattern: Reused enums and constants

Performance Considerations
Line-based Processing: Minimal memory usage for large files

Byte-level Operations: Efficient string processing

Lazy Evaluation: Type conversion only when requested

Table Reuse: Reset pendingAttrs after attachment

Extension Points
New Element Types: Add to ElementTypes enum

New Glyphs: Add to Glyphs and update glyphIsReserved()

Custom Type Converters: Add methods to Element class

Error Handling: Extend ErrorTypes enum

Security Considerations
File I/O: Uses standard Lua io.lines() - ensure proper file permissions

No Code Execution: Purely parses data, no loadstring() or similar

Memory Safety: No recursion or unbounded loops

Input Validation: All input validated against grammar

This module provides a robust, extensible foundation for parsing configuration files with a clean syntax and comprehensive error reporting.