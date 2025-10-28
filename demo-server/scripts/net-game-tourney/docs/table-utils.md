TABLE UTILITIES MODULE
======================

PURPOSE:
Provides common table manipulation functions used throughout the tournament system.

CORE FUNCTIONS:

1. Contains(tbl, value)
   - Linear search through table
   - Returns boolean if value exists

2. deepCopy(obj, ignoreKeys, seen)
   - Creates complete independent copy of nested tables
   - Handles circular references safely
   - Optional ignoreKeys parameter to exclude specific keys
   - Preserves metatables

3. GetAllTiledObjOfXType(area_id, type)
   - Scans Tiled map objects by type/class
   - Returns array of matching objects
   - Used for board detection and interaction

4. SelectRandomItemsFromTableClamped(tbl, limit)
   - Selects random subset of items without duplicates
   - Respects table bounds (won't exceed table size)
   - Used for NPC selection and random matchups

5. deepSearch(tbl, searchKey, searchValue, path)
   - Recursively searches nested tables
   - Returns found status and full path to match
   - Useful for debugging complex data structures

6. shallow_copy(original)
   - Creates top-level copy only (no nested copying)
   - Faster than deepCopy for simple tables

SEARCH UTILITIES:
- searchTable(): Wrapper for deepSearch with formatted output
- Returns dot-notation path to found element (e.g., "participants.3.player_id")

PERFORMANCE NOTES:
- deepCopy should be used sparingly due to recursion overhead
- shallow_copy preferred for simple configuration tables
- GetAllTiledObjOfXType is optimized for Tiled object structure