# July 29 2021 
# Exploring parameters of well mixed model 

# Key parameters are Total Mass, Iterations, outflow rate, and epsilion
# (constructive process - destructive process = 2 epsilion)
include("../src/Chemostats.jl")
include("../src/TimeEvolve.jl")
include("../src/SaveData.jl")
include("process_bson_to_csv.jl")

using DrWatson
using Random 
using JLD2
using FileIO
using Dates
using DataFrames
using Graphs
using GraphIO


function test_chemostat()
    tau_max = 100.0

    mass = 1000
    
    outflow = 1.0
    reaction_rates = [10.0*(1.0/(mass)), 1.0, outflow] # Constructive, destructive, outflow

    molecules = repeat([1], mass)

    well_mixed_chemostat = Chemostat(0, reaction_rates, molecules)
    record = [:molecule_count, :average_length, :complete_timeseries]
    evolution_out = evolve_well_mixed(well_mixed_chemostat, tau_max, 1.0, record)
    save("data/raw/test_run.bson", evolution_out)
    tidy_df = bson_to_tidy_df("data/raw/test_run.bson")
    writedlm("data/raw/test_run.csv",Iterators.flatten(([names(tidy_df)], eachrow(tidy_df))), ',')

end

function logunif(min, max)
    scale = log10(max) - log10(min)
    r = 10^(scale*rand() + log10(min))
    return r 
end


function run_graph_reactions(mass, n_reactors, n_inflow, graph_type, outflow_rate, forward_rate)
    seed = parse(Int64, Dates.format(now(), "SSMMHHddmm"))
    reactor_rates = [forward_rate*(1.0/(mass)), 1.0, outflow_rate] # Constructive, destructive, outflow
    chemostat_specifications = gen_chemostat_spec_list(n_reactors, reactor_rates[1], reactor_rates[2], outflow_rate)
    reactors = Ensemble(n_reactors, graph_type, n_inflow, mass, chemostat_list = chemostat_specifications)

    record = [:molecule_count, :average_length, :var_length, :complete_timeseries]
    evolution_out = evolve_distributed(reactors, 100., 1.0, record, seed)

    d = @strdict n_reactors mass outflow_rate forward_rate graph_type seed
    save_data(evolution_out, d, reactors)

end


