local FormatNumber = {}

local SUFFIXES = {
	"K",
	"M",
	"B",
	"T",
	"Q",
	"QI",
	"SX",
	"SP",
	"OC",
	"NO",
	"DC",
	"UD",
	"DD",
	"TD",
	"QAD",
	"QID",
	"SXD",
	"SPD",
	"OCD",
	"NOD",
	"VG",
	"UVG",
	"DVG",
	"TVG",
	"QAVG",
	"QIVG",
	"SXVG",
	"SPVG",
	"OCVG",
}

function FormatNumber.AddCommas(input: number): string
    if not input then
        return ""
    end

	return (
		tostring(math.modf(input)):reverse():gsub("(%d%d%d)", "%1,"):reverse()
		.. (tostring(input):match("%.%d+") or "")
	):gsub("^,", "")
end

function FormatNumber.Shorten(input: number): string
    if not input then
        return ""
    end

	if input == 0 then
		return "0"
	end

	local suffixIndex = math.min(math.floor(math.log(input, 1000)), #SUFFIXES)
	local v = math.pow(10, suffixIndex * 3)

	return ("%.1f"):format(input / v):gsub("%.?0+$", "") .. (SUFFIXES[suffixIndex] or "")
end

return FormatNumber
