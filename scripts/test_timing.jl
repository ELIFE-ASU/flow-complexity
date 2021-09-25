include("../src/Chemostats.jl")
include("../src/TimeEvolve.jl")
using Random 
using JLD2
using FileIO
using DelimitedFiles
using DataFrames

function time_well_mixed_parameters()
    # Complete exploration of input parameters 
    ϵ_choices = [0.0, 0.0001, 0.001, 0.01, 0.1]
    outflow_choices = [0.0, 0.001, 0.01, 0.1]
    iteration_choices = [100, 200, 500, 1000, 2000, 5000, 10000, 20000]
    mass_choices = [100, 200, 500, 1000, 2000, 5000, 10000, 20000]

    timing_df = DataFrame(ϵ = Float64[], outflow = Float64[], iterations = Int64[], mass = Int64[], time = Float64[])
    ran_first = false
    for mass in mass_choices
        for max_iterations in iteration_choices
            for outflow in outflow_choices
                for ϵ in ϵ_choices
                    well_mixed_rates = [((1.0 - outflow)/2.0) + ϵ, ((1.0 - outflow)/2.0) - ϵ , outflow] # Constructive, destructive, outflow

                    molecules = repeat([1], mass)
                    well_mixed_chemostat = Chemostat(0, [], [], molecules, well_mixed_rates, mass, mass)

                    record = [:molecule_count, :average_length]
                    if !ran_first
                        @elapsed evolution_out = evolve_well_mixed(well_mixed_chemostat, max_iterations, record);
                    end
                    runtime = @elapsed evolution_out = evolve_well_mixed(well_mixed_chemostat, max_iterations, record)
                    results = [ϵ, outflow, max_iterations, mass, runtime]
                    push!(timing_df, results)
                end
            end
        end
    end
    writedlm("data/timing_results.csv", Iterators.flatten(([names(timing_df)], eachrow(timing_df))), ',')
end
