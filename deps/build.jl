# entry point for Pkg: performs all necessary build-time tasks, and writes ext.jl

include("compile.jl")

const config_path = joinpath(@__DIR__, "ext.jl")
const previous_config_path = config_path * ".bak"

function main()
    debug("Performing package build for LLVM.jl from $(pwd())")
    ispath(config_path) && mv(config_path, previous_config_path; remove_destination=true)
    config = Dict{Symbol,Any}()


    ## gather info

    llvms = discover_llvm()
    wrappers = discover_wrappers()
    julia = discover_julia()

    llvm = select_llvm(llvms, wrappers)
    config[:libllvm_version] = llvm.version
    config[:libllvm_path]    = llvm.path
    config[:libllvm_mtime]   = llvm.mtime
    config[:libllvm_mtime]   = llvm.mtime
    config[:libllvm_system]  = use_system_llvm

    llvm_targets = Symbol.(split(read(`$(get(llvm.config)) --targets-built`, String)))
    config[:libllvm_targets] = llvm_targets

    wrapper = select_wrapper(llvm, wrappers)
    config[:llvmjl_wrapper]  = wrapper

    package_commit =
        try
            cd(joinpath(@__DIR__, "..")) do
                chomp(read(`git rev-parse HEAD`, String))
            end
        catch
            warning("could not get LLVM.jl commit")
            # NOTE: we don't explicitly check for commit==nothing, because
            #       it will imply that dirty=true, making us rebuild anyway
            nothing
        end
    config[:package_commit] = package_commit

    package_dirty =
        try
            cd(joinpath(@__DIR__, "..")) do
                length(chomp(read(`git diff --shortstat`, String))) > 0
            end
        catch
            warning("could not get LLVM.jl git status")
            true
        end


    ## build extras library

    config[:libllvm_extra_path] = extras_path
    if !isfile(extras_path) || package_dirty
        compile_extras(llvm, julia)
    end


    ## (re)generate ext.jl

    function globals(mod)
        all_names = names(mod, true)
        filter(name-> !any(name .== [module_name(mod), Symbol("#eval"), :eval]), all_names)
    end

    if isfile(previous_config_path)
        debug("Checking validity of existing ext.jl...")
        @eval module Previous; include($previous_config_path); end
        previous_config = Dict{Symbol,Any}(name => getfield(Previous, name)
                                           for name in globals(Previous))

        if config == previous_config
            info("LLVM.jl has already been built for this toolchain, no need to rebuild")
            mv(previous_config_path, config_path)
            return
        end
    end

    open(config_path, "w") do fh
        write(fh, "# autogenerated file with properties of the toolchain\n")
        for (key,val) in config
            write(fh, "const $key = $(repr(val))\n")
        end
    end

    # refresh the compile cache
    # NOTE: we need to do this manually, as the package will load & precompile after
    #       not having loaded a nonexistent ext.jl in the case of a failed build,
    #       causing it not to precompile after a subsequent successful build.
    if VERSION >= v"0.7.0-DEV.1735" ? Base.JLOptions().use_compiled_modules==1 :
                                      Base.JLOptions().use_compilecache==1
        Base.compilecache("LLVM")
    end

    return
end

main()
