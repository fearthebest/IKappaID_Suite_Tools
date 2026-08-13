-- Server Briefing: shared config and default section catalog.

require "IKST_Shared"
require "IKST_Access"

IKST_Briefing = IKST_Briefing or {}

function IKST_Briefing.enabled()
    if not IKST.isModEnabled() then
        return false
    end
    return IKST_Access.sandboxBool("BriefingEnabled", true)
end

function IKST_Briefing.maxSectionBytes()
    return IKST_Access.sandboxInt("BriefingMaxSectionBytes", 8192, 1024, 32768)
end

function IKST_Briefing.clampBody(text)
    local maxBytes = IKST_Briefing.maxSectionBytes()
    text = tostring(text or "")
    if #text <= maxBytes then
        return text
    end
    return string.sub(text, 1, maxBytes) .. "\n…"
end

-- Default sections ship with the mod. Hosts override via Zomboid/IKST/Briefing/<id>.txt
IKST_Briefing.DEFAULT_SECTIONS = {
    {
        id = "welcome",
        order = 10,
        titleKey = "IGUI_IKST_Briefing_Sec_Welcome",
        title = "Welcome",
        body = table.concat({
            "This server runs IKappaID Suite Tools (IKST) — a Knox County operations layer for claims, recovery, and staff tools.",
            "",
            "Press Ctrl+Shift+W anytime for the IKST panel. Use the Everyone workspace to see your position and vehicle claims.",
            "",
            "Read the sections on the left for rules, enabled features, and how to report problems.",
        }, "\n"),
    },
    {
        id = "rules",
        order = 20,
        titleKey = "IGUI_IKST_Briefing_Sec_Rules",
        title = "Server rules",
        body = table.concat({
            "Replace this section with your house rules.",
            "",
            "Suggested topics:",
            "• PvP and safe zones",
            "• Base building and claim etiquette",
            "• Looting and vehicle theft",
            "• Staff contact and appeal process",
        }, "\n"),
    },
    {
        id = "features",
        order = 30,
        titleKey = "IGUI_IKST_Briefing_Sec_Features",
        title = "IKST features",
        body = table.concat({
            "Claims — Register vehicles and safehouses so only you and guests you allow can use them.",
            "",
            "Recovery journal — Snapshot your character to a journal item and restore after death (when enabled).",
            "",
            "Arrival stabilization — Short deployment grace after join or respawn; zombies ignore you until the timer ends.",
            "",
            "Field recovery — Unstick a claimed or keyed vehicle that flipped nearby (Vehicles addon).",
            "",
            "Staff utilities — Admins use the Utilities and World workspaces; changes are rate-limited and audited when configured.",
        }, "\n"),
    },
    {
        id = "reporting",
        order = 40,
        titleKey = "IGUI_IKST_Briefing_Sec_Reporting",
        title = "Reporting & support",
        body = table.concat({
            "For bugs or feature requests for IKST itself:",
            "• GitHub: fearthebest/IKappaID_Suite_Tools",
            "• Discord: callmekappaid",
            "",
            "For in-game issues on this server, contact staff through your usual channel (Discord, forum, etc.).",
            "",
            "Hosts can override any section by placing a .txt file at:",
            "Zomboid/IKST/Briefing/<section>.txt",
        }, "\n"),
    },
}

function IKST_Briefing.sectionTitle(section)
    if not section then
        return "?"
    end
    if section.titleKey then
        local t = getText and getText(section.titleKey)
        if t and t ~= "" and t ~= section.titleKey then
            return t
        end
    end
    return section.title or section.id or "?"
end

function IKST_Briefing.defaultCatalog()
    local out = {}
    for _, section in ipairs(IKST_Briefing.DEFAULT_SECTIONS) do
        out[#out + 1] = {
            id = section.id,
            order = section.order or 50,
            title = IKST_Briefing.sectionTitle(section),
            titleKey = section.titleKey,
        }
    end
    table.sort(out, function(a, b)
        return (tonumber(a.order) or 50) < (tonumber(b.order) or 50)
    end)
    return out
end

function IKST_Briefing.defaultBody(sectionId)
    for _, section in ipairs(IKST_Briefing.DEFAULT_SECTIONS) do
        if section.id == sectionId then
            return IKST_Briefing.clampBody(section.body or "")
        end
    end
    return ""
end
