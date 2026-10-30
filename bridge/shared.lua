-- Bridge - shared helpers (formatting, distance, clamping).

Shared = {}

function Shared.Truncate(text, maxLength)
    if type(text) ~= 'string' then return '' end
    if #text <= maxLength then return text end
    return (text:sub(1, maxLength - 3)) .. '...'
end

function Shared.FormatMoney(amount)
    local formatted = tostring(math.floor(amount or 0))
    local sign = ''
    if formatted:sub(1, 1) == '-' then
        sign = '-'
        formatted = formatted:sub(2)
    end

    local result = formatted:reverse():gsub('(%d%d%d)', '%1,'):reverse()
    result = result:gsub('^,', '')

    return ('%s$%s'):format(sign, result)
end

function Shared.Distance(coords1, coords2)
    return #(coords1 - coords2)
end

function Shared.IsNear(coords, target, radius)
    return Shared.Distance(coords, target) <= radius
end

function Shared.Clamp(value, min, max)
    if value < min then return min end
    if value > max then return max end
    return value
end
