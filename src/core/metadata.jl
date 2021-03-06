export DEBUG_METADATA_VERSION, MDString, MDNode, operands

@checked struct MetadataAsValue <: Value
    ref::reftype(Value)
end
identify(::Type{Value}, ::Val{API.LLVMMetadataAsValueValueKind}) = MetadataAsValue

# NOTE: the C API doesn't allow us to differentiate between MD kinds,
#       all are wrapped by the opaque MetadataAsValue...

const MDString = MetadataAsValue

MDString(val::String) = MDString(API.LLVMMDString(val, Cuint(length(val))))

MDString(val::String, ctx::Context) = 
    MDString(API.LLVMMDStringInContext(ref(ctx), val, Cuint(length(val))))

function Base.convert(::Type{String}, md::MDString)
    len = Ref{Cuint}()
    ptr = API.LLVMGetMDString(ref(md), len)
    ptr == C_NULL && throw(ArgumentError("invalid metadata, not a MDString?"))
    return unsafe_string(convert(Ptr{Int8}, ptr), len[])
end

# TODO: make this init-time constant
DEBUG_METADATA_VERSION() = API.LLVMGetDebugMDVersion()


const MDNode = MetadataAsValue

MDNode(vals::Vector{T}) where {T<:Value} =
    MDNode(API.LLVMMDNode(ref.(vals), Cuint(length(vals))))

MDNode(vals::Vector{T}, ctx::Context) where {T<:Value} =
    MDNode(API.LLVMMDNodeInContext(ref(ctx), ref.(vals),
                                   Cuint(length(vals))))

function operands(md::MDNode)
    nops = API.LLVMGetMDNodeNumOperands(ref(md))
    ops = Vector{API.LLVMValueRef}(uninitialized, nops)
    API.LLVMGetMDNodeOperands(ref(md), ops)
    return Value.(ops)
end
