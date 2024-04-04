"""

##########################################################################

ENSEMBLE



##########################################################################

"""

# include("Chemostats.jl")
#p3: to remove

using Graphs
using StatsBase

"""

##########################################################################
ENSEMBLE STRUCT

This type contains all the information needed to run the time evolution
across spatial locations.
##########################################################################

    reactor_ids     (int array)         = unique reactor IDs
    reactors        (Chemostat array)   = chemostats
    ensemble_graph  (DiGraph)           = how are the reactors connected (using Graph type from Graphs.jl)
    inflow_ids      (int array)         = which reactors are sources? #p1 to specify

##########################################################################

"""

mutable struct Ensemble

    reactor_ids     ::Array{Int64,1}
    reactors        ::Array{Chemostat,1}
    ensemble_graph  ::DiGraph
    inflow_ids      ::Array{Int64,1}

end

"""

##########################################################################
GENERATOR FOR THE ENSEMBLE STRUCT

Parametrizes the Ensemble struct.
##########################################################################

Input:

    N_reactors      (int)           = number of reactors
    graph_type      (string)        = graph type
    N_sources       (int)           = #p1 to complete
    mass            (int)           = #p1 to complete
    chemostat_list  (dict vector)   = list of chemostats

Output:

    Ensemble        (Ensemble)      = resulting ensemble

##########################################################################

"""

function Ensemble(N_reactors        ::Int64, 
                  graph_type        ::String, 
                  N_sources         ::Int64, 
                  mass              ::Int64;
                  chemostat_list    = Vector{Dict{String,Any}}[]
                  )

    # Erdos-Renyi (random) graph
    if graph_type == "ER"

        # create ER graph with N_reactors vertices of degree 4 #p1: why four edges?
        ensemble_graph = erdos_renyi(N_reactors, 4*N_reactors, is_directed =true)

        # Get inflow ids and make sure its a connected component #p1: what
        inflow_ids, ensemble_graph = find_inflow_nodes(ensemble_graph, N_sources)

        # Get chemostats specifications  #p1: what
        chemostat_specs = sample(chemostat_list, N_reactors)

        # Get chemostat vector from specifications  #p1: what
        chemostats = chemostats_from_specs(ensemble_graph, chemostat_specs, inflow_ids, mass)

    # Barabasi-Albert (scale-free) graph
    elseif graph_type == "BA"

        # create BA graph with N_reactors vertices of degree 4 #p1: why two edges?
        ensemble_graph = barabasi_albert(N_reactors, 2, is_directed=true) # Check why is this 2?

        # Get inflow ids  #p1: what
        inflow_ids, ensemble_graph  = find_inflow_nodes(ensemble_graph, N_sources)

        # Get chemostats specifications  #p1: what
        chemostat_specs = sample(chemostat_list, N_reactors)

        # Get chemostat vector from specifications  #p1: what
        chemostats = chemostats_from_specs(ensemble_graph, chemostat_specs, inflow_ids, mass)

    # regular graph (each node has the same degree)
    elseif graph_type == "regular"

        # create regular graph with N_reactors vertices of degree 4
        ensemble_graph = random_regular_digraph(N_reactors, 4)

        # Get inflow ids #p1: what
        inflow_ids, ensemble_graph = find_inflow_nodes(ensemble_graph, N_sources)

        # Get chemostats specifications  #p1: what
        chemostat_specs = sample(chemostat_list, N_reactors)

        # Get chemostat vector from specifications  #p1: what
        chemostats = chemostats_from_specs(ensemble_graph, chemostat_specs, inflow_ids, mass)
    
    # lattice graph
    elseif graph_type == "lattice"

        # check if N_reactors is a square
        if (round(sqrt(N_reactors)))^2 != N_reactors
            error("Lattice requested but N_reactors isn't square")
        end 

        # create lattice digraph
        ensemble_graph = lattice_digraph(N_reactors)

        # Get inflow ids #p1: what
        inflow_ids, ensemble_graph  = find_inflow_nodes(ensemble_graph, N_sources)

        # Get chemostats specifications  #p1: what
        chemostat_specs = sample(chemostat_list, N_reactors)

        # Get chemostat vector from specifications  #p1: what
        chemostats = chemostats_from_specs(ensemble_graph, chemostat_specs, inflow_ids, mass)

    # line (path) digraph
    elseif graph_type == "line"

        # check if  #p1: what
        if N_sources > 1
            error("Line Graph specified but N_sources > 1")
        end

        # create a path graph with N_reactors vertices
        ensemble_graph = path_digraph(N_reactors)

        # Specify inflow  #p1: what
        inflow_ids = [1]

        # Get the chemostats #p1: what
        chemostat_specs = sample(chemostat_list, N_reactors)

        # Get chemostat vector from specifications  #p1: what
        chemostats = chemostats_from_specs(ensemble_graph, chemostat_specs, inflow_ids, mass)

    end

    # return the Ensemble
    return Ensemble(collect(1:N_reactors),
                    chemostats,
                    ensemble_graph,
                    inflow_ids,
                    )

end

"""

##########################################################################
CREATE A LATTICE DIGRAPH

Creates a lattice digraph with N nodes.
##########################################################################

Input:

    N       (int)       = number of nodes

Output:

    L       (DiGraph)   = lattice digraph

##########################################################################

"""

function lattice_digraph(N)

    # construct a simple digraph with N vertices (and 0 edges)
    L = SimpleDiGraph(N)

    # link the vertices together (add edges) to form the lattice
    n = sqrt(N)
    rows = []
    current = 0
    for i in 1:n
        for j in 0:(n-1)
            current_node = i + n*j  
            right_neighbor = current_node + 1
            down_neighbor = current_node + n 
            if i < n
                add_edge!(L,(current_node, right_neighbor))
            end
            add_edge!(L, (current_node, down_neighbor))
        end
    end

    # return the graph
    return L 

end

"""

##########################################################################
#p1
(not too sure here)

(we’re gonna want to connect edges that have to in-flow to them to other
chemostats I guess?)
##########################################################################

Input:

    graph       = graph we’re working on
    n_sources   = #p1: no idea

Output:

    source_list = #p1: no idea
    graph       = same graph as input

##########################################################################

"""

function find_inflow_nodes(graph, 
                           n_sources
                           )

    # Find the nodes that have no in-edges
    total_edges = length(edges(graph))

    # get the in-degree for each node
    in_degrees = indegree(graph, vertices(graph))
    # determine which node has no in-edge
    no_in_nodes = [i for i in 1:length(in_degrees) if in_degrees[i] == 0]
    # sort nodes by in-degree
    sorted_nodes = sort!(collect(vertices(graph)), by = x->indegree(graph,x))
    # determine how many nodes have no in-edge
    num_no_in = length(no_in_nodes)

    #p1: not too sure I understand what the rest is about
    if num_no_in >= n_sources
        # You're good just pick a sample of those with 0 in in_degrees
        no_in_nodes = [i for i in 1:length(in_degrees) if in_degrees[i] == 0]
        source_list = sort!(sample(no_in_nodes, n_sources, replace=false))


    else
        # You're going to need to modify the graph to make it work
        source_list = Int64[]
        # Remove the number of nodes you need 
        nodes_to_remove = sorted_nodes[1:n_sources]
        rem_vertices!(graph, nodes_to_remove)
        # Get the remaining nodes 
        other_nodes = collect(vertices(graph))
        # Make the remaining graph a completely connected graph
        components = connected_components(graph)
        while length(components) > 1
            add_edge!(graph, rand(components[1]), rand(components[2]))
            components = connected_components(graph)
        end
        # Now we're going to connect the source nodes to random other nodes
        random_connections = sample(vertices(graph), n_sources)
        for i in 1:n_sources
            add_vertex!(graph)
            new_node = length(vertices(graph))
            add_edge!(graph, new_node, random_connections[i])
            push!(source_list, new_node)
        end

    end

    # Tidy up by making sure you've got the right number of edges
    new_edge_count = length(edges(graph))
    total_edges - new_edge_count
    while total_edges - new_edge_count > 0
        source_node = sample(vertices(graph))
        destination_node = sample(other_nodes)
        add_edge!(graph, source_node, destination_node)
        new_edge_count = length(edges(graph))
    end

    return source_list, graph

end

"""

##########################################################################
CALCULATE NEXT REACTION TIMES

Calculate the next reaction time for each set of propensities.
##########################################################################

Input:

    all_propensities    = propensities calculated from chemostat
    tau                 = #p1 no idea

Output:

    reactor_steps       = #p1 no idea

##########################################################################

"""

function calc_next_rxn_times(all_propensities, 
                             tau
                             )

    # Update time 

    # how many different propensities do we have?
    n = length(all_propensities)

    # sum these up
    total_p = sum.(all_propensities)
    # print(total_p)

    # #p1: no idea
    tau_steps = -log.(rand(n))./total_p

    # #p1: no idea
    reactor_steps = collect(zip(tau_steps .+ tau, 1:n))

    # #p1: no idea
    reactor_steps = sort(reactor_steps, by = x->x[1])

    # println(reactor_steps)

    # #p1 no idea
    return reactor_steps

end

"""

##########################################################################
CREATE A SET OF CHEMOSTATS FOR A GRAPH

Get a set of chemostats with the correct specifications for a graph, 
including neighbor nodes.
##########################################################################

Input:

    ensemble_graph      = the graph specified for the ensemble
    chemostat_specs     = chemostat specs
    inflow_ids          = #p1 don’t know
    mass                = total mass of the molecules inside the chemostat

Output:

    chemostat_list      = list of chemostats created

##########################################################################

"""

function chemostats_from_specs(ensemble_graph, 
                               chemostat_specs,
                               inflow_ids, 
                               mass)

    # Make the chemostats with the right neighbors 

    # create the list of chemostats
    chemostat_list = Chemostat[]

    # p1: what
    reactors = collect(vertices(ensemble_graph))

    # go over each reactor
    for r in reactors

        #p1 why sample?
        specs = sample(chemostat_specs)

        # get reaction rate constants and list of stabilized integers for this reactor
        reaction_rate_constants = specs["reaction_rate_constants"]
        stabilized_integers = specs["stabilized_integers"]

        # get the neighbors for chemostat r
        these_neigbors = neighbors(ensemble_graph, r)

        #p1 if the chemostat is in "inflow_ids" fill it with molecules
        if r in inflow_ids

            # create a list of length "mass" filled with molecules of size 1
            molecules = repeat([1], mass)

            #p1 what
            mass_fixed= true

            # instantiate the chemostat
            this_chemostat = Chemostat(r, reaction_rate_constants,
                                        molecules = molecules,
                                        mass_fixed = mass_fixed,
                                        neighbors = these_neigbors,
                                        stabilized_integers = stabilized_integers)

            # add the chemostat to the list of chemostats
            push!(chemostat_list, this_chemostat)

        #p1 if not then do not fill it
        else

            # instantiate the chemostat
            this_chemostat = Chemostat(r, reaction_rate_constants, 
                                        neighbors = these_neigbors,
                                        stabilized_integers = stabilized_integers)

            # add the chemostat to the list of chemostats
            push!(chemostat_list, this_chemostat)
        end

    end

    # return the list of chemostats
    return chemostat_list

end

"""

##########################################################################
GENERATE LIST OF CHEMOSTAT SPECS

This function will generate a list of chemostat identical specifications which
can be passed to the Ensemble constructor.
##########################################################################

Input:

    N_chemostats    = number of chemostats specs to generate
    forward_rate    = rate for constructive reactions
    backward_rate   = rate for destructive reactions
    outflow         = rate for outflow reactions

Output:

    spec_list       = chemostat spec list generated

##########################################################################

"""

function gen_chemostat_spec_list(N_chemostats   ::Int64,
                                 forward_rate   ::Float64,
                                 backward_rate  ::Float64,
                                 outflow        ::Float64
                                 )

    # dictionary template for chemostat specs
    single_dict = Dict("reaction_rate_constants" => [forward_rate, backward_rate, outflow],
                        "stabilized_integers" => Int64[])

    # create the array of chemostat specs
    spec_list = [single_dict]

    # fill the array with identical copies of the template
    for n in 1:(N_chemostats-1)
        new_spec = copy(single_dict)
        push!(spec_list, new_spec)
    end

    # return the list of chemostat specs
    return spec_list 
    
end
