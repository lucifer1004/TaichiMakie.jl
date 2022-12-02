function getbitmap(glyph)
    DEFAULT_FACE.load_char(glyph)
    bm = DEFAULT_FACE.glyph.bitmap
    h = pyconvert(Int, bm.rows)
    w = pyconvert(Int, bm.width)
    @show h, w
    data = collect(reshape(pyconvert(Vector, bm.buffer), (w, h))')
    return data
end
