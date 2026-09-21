-- Minimal reproduction for: SavedVariables written but never restored.
-- Expected: the login counter increases by 1 every login.
-- Actual  : it is always 1, because SVReproDB is nil at ADDON_LOADED even
--           though the previous session wrote it to disk correctly.

local addonName = ...

local f = CreateFrame("Frame")
f:RegisterEvent("ADDON_LOADED")
f:SetScript("OnEvent", function(self, event, loaded)
    if loaded ~= addonName then return end

    print("|cffffff00SVRepro|r: at ADDON_LOADED, SVReproDB is " .. type(SVReproDB))

    if type(SVReproDB) ~= "table" then SVReproDB = {} end
    SVReproDB.logins = (SVReproDB.logins or 0) + 1

    print("|cffffff00SVRepro|r: login count = " .. SVReproDB.logins
        .. "  (should increase every login; stays 1 when the bug is present)")

    self:UnregisterEvent("ADDON_LOADED")
end)
