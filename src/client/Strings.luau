-- Localized strings from LocalizationService.Strings (RU/EN).
local LocalizationService = game:GetService("LocalizationService")
local Players = game:GetService("Players")

local SUPPORTED = { en = true, ru = true }

-- Our strings live in a local LocalizationTable, so ask that table directly
-- (GetTranslatorForPlayerAsync only serves the cloud table).
local function makeTranslator(): Translator?
	local tableInstance = LocalizationService:WaitForChild("Strings", 10) :: LocalizationTable?
	if not tableInstance then
		return nil
	end
	local locale = string.lower(string.sub(Players.LocalPlayer.LocaleId, 1, 2))
	if not SUPPORTED[locale] then
		locale = "en"
	end
	local ok, result = pcall(tableInstance.GetTranslator, tableInstance, locale)
	return if ok then result else nil
end

local translator = makeTranslator()

local Strings = {}

function Strings.get(key: string, args: { [string]: any }?): string
	if translator then
		local ok, text = pcall(translator.FormatByKey, translator, key, args or {})
		if ok then
			return text
		end
	end
	return key
end

-- 1234 -> "1.2K"
function Strings.num(n: number): string
	local abs = math.abs(n)
	for _, unit in { { 1e9, "B" }, { 1e6, "M" }, { 1e3, "K" } } do
		if abs >= unit[1] then
			return (string.format("%.1f%s", n / unit[1], unit[2]):gsub("%.0(%a)", "%1"))
		end
	end
	return tostring(math.floor(n))
end

return Strings
