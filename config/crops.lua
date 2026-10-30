-- Config - crop definitions.

Config.Crops = {
    {
        key = 'apple',
        label = 'Apple',
        basePrice = 50,
        yield = { min = 1, max = 3 },
        qualities = {
            { quality = 0, weight = 25 },
            { quality = 1, weight = 50 },
            { quality = 2, weight = 25 },
        },
        icon = 'apple.png',
    },

    {
        key = 'tomato',
        label = 'Tomato',
        basePrice = 40,
        yield = { min = 1, max = 4 },
        qualities = {
            { quality = 0, weight = 25 },
            { quality = 1, weight = 50 },
            { quality = 2, weight = 25 },
        },
        icon = 'tomato.png',
    },

    {
        key = 'corn',
        label = 'Corn',
        basePrice = 30,
        yield = { min = 2, max = 5 },
        qualities = {
            { quality = 0, weight = 30 },
            { quality = 1, weight = 50 },
            { quality = 2, weight = 20 },
        },
        icon = 'corn.png',
    },

    {
        key = 'orange',
        label = 'Orange',
        basePrice = 65,
        yield = { min = 1, max = 3 },
        qualities = {
            { quality = 0, weight = 25 },
            { quality = 1, weight = 50 },
            { quality = 2, weight = 25 },
        },
        icon = 'orange.png',
    },
}

Config.CropMap = {}
for _, crop in ipairs(Config.Crops) do
    Config.CropMap[crop.key] = crop
end
