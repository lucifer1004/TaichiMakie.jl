const DEFAULT_GLYPH_PIXEL_SIZE = Ref{Int}(128)

function getbitmap(font, glyph)
    face = Makie.to_font(font)
    FreeTypeAbstraction.set_pixelsize(face, DEFAULT_GLYPH_PIXEL_SIZE[])
    bmp, metric = renderface(face, glyph, DEFAULT_GLYPH_PIXEL_SIZE[])
    return bmp', metric
end
