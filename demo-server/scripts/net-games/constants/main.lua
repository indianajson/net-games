local helpers = require('/scripts/net-games/helpers')

local asset_directories = require('/scripts/net-games/constants/asset-directories')
local asset_bundles = require('/scripts/net-games/constants/asset_bundles')
local strings = require('/scripts/net-games/constants/strings')

local CONSTANTS = {}

local function _handle_set(set_this, value)
    if (type(set_this) ~= "string") then
        print("`set_this` was not a string. Please provide a string value that is the name of the `key` in `CONFIG`")
        return
    end
    local copy = helpers.deep_copy(value)
    CONSTANTS[set_this] = copy
end

_handle_set("Asset_Directories", asset_directories)
_handle_set("Asset_Bundles", asset_bundles)
_handle_set("Strings", strings)

return CONSTANTS
