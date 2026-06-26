-- Vehicle / item catalog helpers (display name + full id).

require "IKST_Shared"
require "IKST_Utility"

IKST_Catalog = IKST_Catalog or {}
IKST_Catalog.MAX_LIST_ROWS = 200
IKST_Catalog.CATEGORY_ALL = "all"

function IKST_Catalog.normalizeCategoryId(raw)
    local key = string.lower(tostring(raw or "other"))
    key = string.gsub(key, "%s+", "_")
    key = string.gsub(key, "[^%w_]", "")
    if key == "" then
        key = "other"
    end
    return key
end

function IKST_Catalog.prettyCategoryLabel(raw)
    local label = tostring(raw or "Other")
    if label == "" then
        return "Other"
    end
    return label
end

function IKST_Catalog.itemBucketFromCategory(raw)
    local c = string.lower(tostring(raw or ""))
    if c == "" then
        return "Other"
    end
    if string.find(c, "weapon", 1, true) or string.find(c, "firearm", 1, true) then
        return "Weapons"
    end
    if string.find(c, "ammo", 1, true) then
        return "Ammo"
    end
    if string.find(c, "food", 1, true) or string.find(c, "cooking", 1, true) or string.find(c, "drink", 1, true) then
        return "Food & drink"
    end
    if string.find(c, "medical", 1, true) or string.find(c, "firstaid", 1, true) or string.find(c, "health", 1, true) then
        return "Medical"
    end
    if string.find(c, "clothing", 1, true) or string.find(c, "appearance", 1, true) or string.find(c, "accessory", 1, true) then
        return "Clothing"
    end
    if string.find(c, "literature", 1, true) or string.find(c, "skill", 1, true) or string.find(c, "book", 1, true) then
        return "Books"
    end
    if string.find(c, "container", 1, true) or string.find(c, "bag", 1, true) then
        return "Bags & containers"
    end
    if string.find(c, "vehicle", 1, true) or string.find(c, "mechanic", 1, true) then
        return "Vehicle parts"
    end
    if string.find(c, "farming", 1, true) or string.find(c, "material", 1, true) or string.find(c, "resource", 1, true) then
        return "Materials"
    end
    if string.find(c, "tool", 1, true) or string.find(c, "camping", 1, true) or string.find(c, "electronic", 1, true) then
        return "Tools"
    end
    return "Other"
end

function IKST_Catalog.itemCategoryFromScript(item)
    if item and item.getDisplayCategory then
        local cat = item:getDisplayCategory()
        if cat ~= nil then
            if type(cat) == "string" and cat ~= "" then
                return cat
            end
            if type(cat) == "table" and cat.toString then
                local s = cat:toString()
                if s and s ~= "" then
                    return s
                end
            end
            local asText = tostring(cat)
            if asText and asText ~= "" and not string.find(asText, "java%.") then
                return asText
            end
        end
    end
    return "Other"
end

function IKST_Catalog.vehicleCategoryFromScript(script, shortName)
    if script and script.getMechanicType then
        local mt = script:getMechanicType()
        if mt ~= nil then
            local label = tostring(mt)
            if label ~= "" and label ~= "0" and label ~= "nil" then
                return label
            end
        end
    end
    local s = string.lower(shortName or "")
    if string.find(s, "trailer", 1, true) then
        return "Trailer"
    end
    if string.find(s, "burnt", 1, true) or string.find(s, "wreck", 1, true) then
        return "Wreck"
    end
    if string.find(s, "bus", 1, true) then
        return "Bus"
    end
    if string.find(s, "van", 1, true) or string.find(s, "step", 1, true) then
        return "Van"
    end
    if string.find(s, "truck", 1, true) or string.find(s, "semi", 1, true) then
        return "Truck"
    end
    if string.find(s, "moto", 1, true) or string.find(s, "bike", 1, true) then
        return "Motorcycle"
    end
    if string.find(s, "suv", 1, true) or string.find(s, "offroad", 1, true) or string.find(s, "4x4", 1, true) then
        return "SUV / 4x4"
    end
    if string.find(s, "police", 1, true) or string.find(s, "ambulance", 1, true) or string.find(s, "fire", 1, true) then
        return "Emergency"
    end
    return "Car"
end

function IKST_Catalog.matchesCategory(entry, categoryId)
    if not categoryId or categoryId == "" or categoryId == IKST_Catalog.CATEGORY_ALL then
        return true
    end
    return IKST_Catalog.normalizeCategoryId(entry.category) == categoryId
end

function IKST_Catalog.listCategories(catalog, allLabel)
    local seen = {}
    local out = { { id = IKST_Catalog.CATEGORY_ALL, label = allLabel or "All" } }
    for _, entry in ipairs(catalog or {}) do
        local id = IKST_Catalog.normalizeCategoryId(entry.category)
        if not seen[id] then
            seen[id] = true
            out[#out + 1] = {
                id = id,
                label = IKST_Catalog.prettyCategoryLabel(entry.category),
            }
        end
    end
    table.sort(out, function(a, b)
        if a.id == IKST_Catalog.CATEGORY_ALL then
            return true
        end
        if b.id == IKST_Catalog.CATEGORY_ALL then
            return false
        end
        return a.label < b.label
    end)
    return out
end

function IKST_Catalog.filterEntries(catalog, categoryId, filterText, maxRows)
    filterText = string.lower(filterText or "")
    maxRows = maxRows or IKST_Catalog.MAX_LIST_ROWS
    local out = {}
    local total = 0
    for _, entry in ipairs(catalog or {}) do
        if IKST_Catalog.matchesCategory(entry, categoryId) then
            if filterText == "" or string.find(entry.search or "", filterText, 1, true) then
                total = total + 1
                if #out < maxRows then
                    out[#out + 1] = entry
                end
            end
        end
    end
    return out, total
end

function IKST_Catalog.normalizeFullId(name, defaultModule)
    name = string.gsub(tostring(name or ""), "^%s*(.-)%s*$", "%1")
    if name == "" then
        return nil
    end
    if not string.find(name, "%.") then
        name = (defaultModule or "Base") .. "." .. name
    end
    return name
end

function IKST_Catalog.vehicleDisplayName(shortName)
    if not shortName or shortName == "" then
        return shortName
    end
    if getText then
        local translated = getText("IGUI_VehicleName" .. shortName)
        if translated and translated ~= "" and not string.find(translated, "IGUI_") then
            return translated
        end
    end
    return shortName
end

function IKST_Catalog.buildVehicleCatalog()
    local catalog = {}
    local seen = {}
    if getScriptManager and getScriptManager().getAllVehicleScripts then
        local scripts = getScriptManager():getAllVehicleScripts()
        IKST.forEachJavaCollection(scripts, function(script)
            if script and script.getName then
                local full = IKST_Catalog.normalizeFullId(script:getName(), "Base")
                if full and not seen[full] then
                    seen[full] = true
                    local shortName = string.match(full, "%.(.+)$") or full
                    local label = IKST_Catalog.vehicleDisplayName(shortName)
                    local category = IKST_Catalog.vehicleCategoryFromScript(script, shortName)
                    catalog[#catalog + 1] = {
                        full = full,
                        short = shortName,
                        label = label,
                        category = category,
                        search = string.lower(label .. " " .. full .. " " .. shortName .. " " .. category),
                    }
                end
            end
        end)
    end
    table.sort(catalog, function(a, b)
        return a.label < b.label
    end)
    if #catalog == 0 then
        catalog[1] = {
            full = "Base.CarNormal",
            short = "CarNormal",
            label = "CarNormal",
            category = "Car",
            search = "carnormal base.carnormal car",
        }
    end
    return catalog
end

function IKST_Catalog.vehicleScriptExists(scriptName)
    scriptName = IKST_Catalog.normalizeFullId(scriptName, "Base")
    if not scriptName then
        return false
    end
    if getVehicleScript then
        local script = getVehicleScript(scriptName)
        if script then
            return true
        end
    end
    local sm = getScriptManager and getScriptManager()
    if sm and sm.getVehicleScript then
        if sm:getVehicleScript(scriptName) then
            return true
        end
    end
    local short = string.match(scriptName, "%.(.+)$")
    for _, entry in ipairs(IKST_Catalog.buildVehicleCatalog()) do
        if entry.full == scriptName or entry.short == short then
            return true
        end
    end
    return false
end

function IKST_Catalog.itemDisplayName(fullType)
    if not fullType or fullType == "" then
        return fullType
    end
    if getItemNameFromFullType then
        local name = getItemNameFromFullType(fullType)
        if name and name ~= "" then
            return name
        end
    end
    if getScriptManager then
        local sm = getScriptManager()
        if sm and sm.FindItem then
            local item = sm:FindItem(fullType)
            if item and item.getDisplayName then
                return item:getDisplayName()
            end
        end
    end
    return string.match(fullType, "%.(.+)$") or fullType
end

function IKST_Catalog.buildItemCatalog()
    local catalog = {}
    local seen = {}
    local sm = getScriptManager and getScriptManager()
    if sm and sm.getAllItems then
        IKST.forEachJavaCollection(sm:getAllItems(), function(item)
            if item and item.getFullName then
                local full = item:getFullName()
                if full and full ~= "" and not seen[full] then
                    seen[full] = true
                    local label = IKST_Catalog.itemDisplayName(full)
                    local rawCategory = IKST_Catalog.itemCategoryFromScript(item)
                    local category = IKST_Catalog.itemBucketFromCategory(rawCategory)
                    catalog[#catalog + 1] = {
                        full = full,
                        label = label,
                        category = category,
                        rawCategory = rawCategory,
                        search = string.lower(label .. " " .. full .. " " .. category .. " " .. rawCategory),
                    }
                end
            end
        end)
    end
    table.sort(catalog, function(a, b)
        return a.label < b.label
    end)
    if #catalog == 0 then
        catalog[1] = { full = "Base.Axe", label = "Axe", category = "Tool", search = "axe base.axe tool" }
    end
    return catalog
end

function IKST_Catalog.itemExists(itemType)
    itemType = IKST_Catalog.normalizeFullId(itemType, "Base")
    if not itemType then
        return false
    end
    if getScriptManager then
        local sm = getScriptManager()
        if sm and sm.FindItem and sm:FindItem(itemType) then
            return true
        end
    end
    return false
end
