struct TaichiField
    snode::Py
    field::Py
end

function _get_ti_indices(shape)
    if length(shape) == 1
        return ti.i
    elseif length(shape) == 2
        return ti.ij
    end
end

function TaichiField(len, dtype, shape)
    builder = ti.FieldsBuilder()
    if len == 1
        field = ti.field(dtype)
    else
        field = ti.Vector.field(len, dtype)
    end
    builder.dense(_get_ti_indices(shape), shape).place(field)
    snode = builder.finalize()
    return TaichiField(snode, field)
end

function Base.push!(f::TaichiField, x)
    f.field.from_numpy(np.array(x))
end

function destroy!(f::TaichiField)
    f.snode.destroy()
end
