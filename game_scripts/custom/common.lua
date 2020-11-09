local common = {}

function Set (list)
    local set = {}
    for _, l in ipairs(list) do set[l] = true end
    return set
end

function sampleInternal(set, m, n, randomFn)
    if n == 0 or m == 0 then
        return {}
    end

    local item
    local i = randomFn(n)
    for key, _ in pairs(set) do 
        if i == 0 then            
            item = key
            set[key] = nil
            break
        end
        i = i - 1
    end

    local ret = sampleInternal(set, m - 1, n - 1, randomFn)
    ret[#ret + 1] = item
    return ret
end

function common:iterateLines(str)
    local i = 1
    function iter()
        if i == -1 then return nil end
        local newi = string.find(str, "\n", i+1)
        if newi == nil then
            i = -1
            return string.sub(str, i)
        end

        local ret
        if string.sub(str, newi - 1) == '\r' then
            ret = string.sub(str, i, newi - 2)
        else
            ret = string.sub(str, i, newi - 1)
        end
        i = newi + 1
        return ret
    end
    return iter
end

function common:sample(xs, n, randomFn)
    if n == 0 then
        return {}
    end

    local set = Set(xs)
    return sampleInternal(set, #xs, n, randomFn)
end

return common