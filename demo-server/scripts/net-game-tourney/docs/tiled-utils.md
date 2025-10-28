TILED UTILITIES MODULE
======================

PURPOSE:
Provides helper functions for interacting with Tiled map editor custom properties
and object data.

SINGLE FUNCTION:

check_custom_prop_validity(object_props, custom_prop_name, empty_string_is_valid)

PARAMETERS:
- object_props: Table of custom properties from Tiled object
- custom_prop_name: Specific property to check
- empty_string_is_valid: Optional boolean for empty string handling

RETURN VALUE:
- boolean: True if property exists and meets validity criteria

VALIDATION LOGIC:

1. Basic Existence Check:
   - Returns false if object_props or custom_prop_name are nil
   - Returns false if property doesn't exist

2. Empty String Handling:
   - When empty_string_is_valid = true: Property exists → valid
   - When empty_string_is_valid = false/unspecified: Property exists AND not empty → valid

USE CASES:

Board Background Detection:
- Checks "Board Background" custom property
- Ensures theme selection is valid

Warp Direction Validation:
- Verifies direction properties exist
- Ensures valid direction values

Generic Property Checking:
- Any Tiled custom property validation
- Prevents errors from missing properties

EXAMPLE USAGE:

local isValid = TiledUtils.check_custom_prop_validity(
    object.custom_properties, 
    "Board Background"
)

if isValid then
    -- Apply board theme
else
    -- Use default theme
end

ERROR PREVENTION:
- Safely handles nil object properties
- Prevents crashes from missing custom properties
- Consistent validation across all Tiled interactions