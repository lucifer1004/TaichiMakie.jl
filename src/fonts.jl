const DEFAULT_FACE = Ref{Union{FTFont, Nothing}}(nothing)
const DEFAULT_GLYPH_PIXEL_SIZE = Ref{Int}(128)

function getbitmap(glyph)
    # Why do we need to add 2 here?
    bmp, metric = renderface(DEFAULT_FACE[], glyph + 2, DEFAULT_GLYPH_PIXEL_SIZE[])
    return bmp', metric
end
