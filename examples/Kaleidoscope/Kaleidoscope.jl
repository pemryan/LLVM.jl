module Kaleidoscope

import LLVM
using Unicode

include("lexer.jl")
include("ast.jl")
include("scope.jl")
include("codegen.jl")
include("run.jl")

end # module
