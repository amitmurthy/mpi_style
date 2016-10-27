addprocs(4)
push!(LOAD_PATH, "/Users/amitm/Julia/mpi_style")
@everywhere importall MPIStyle
init_comm_channels()

@everywhere begin
    if myid() == 1
        sendto(2, "Hello World!")
    elseif myid() == 2
        println(recvfrom_(1))
    end
    stime = rand(1:5)
    println("Sleeping for $stime seconds")
    sleep(stime)
    barrier()
    println("Out of barrier")

    bcast_val = nothing
    if myid() == 1
        bcast_val = rand(2)
    end

    bcast_val = bcast(bcast_val, 1)
    println("recd broadcasted val $bcast_val")

    scatter_data = nothing
    if myid() == 1
        scatter_data = rand(Int8, nprocs())
        println("scattering $scatter_data")
    end
    lp = scatter(scatter_data, 1)
    println("localpart $lp")

    scatter_data = nothing
    if myid() == 1
        scatter_data = rand(Int8, nprocs()*2)
        println("scattering $scatter_data")
    end
    lp = scatter(scatter_data, 1)
    println("localpart $lp")

    gathered_data = gather(myid(), 1)
    if myid() == 1
        println("gather $gathered_data")
    end

    sleep(1.0) # Need to implement peek and ordering of messages. Till then....

    gathered_data = gather([myid(), myid()], 1)
    if myid() == 1
        println("gather $gathered_data")
    end

end


