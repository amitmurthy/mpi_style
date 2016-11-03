addprocs(4)
push!(LOAD_PATH, ".")
using MPIStyle
@everywhere importall MPIStyle
init_comm_channels()

@everywhere begin
    if myid() == 1
        data = "Hello from 1"
        println("Sending from 1 '$data'")
        sendto(2, data)
    elseif myid() == 2
        println(recvfrom_(1))
    end
    stime = rand(1:5)
    println("Sleeping for $stime seconds")
    sleep(stime)
    barrier()
    println("Exiting barrier")

    bcast_val = nothing
    if myid() == 1
        bcast_val = rand(2)
    end

    bcast_val = bcast(bcast_val, 1)
    println("recd broadcasted val $bcast_val")

    barrier()

    scatter_data = nothing
    if myid() == 1
        scatter_data = rand(Int8, nprocs())
        println("scattering $scatter_data")
    end
    lp = scatter(scatter_data, 1, tag=1)
    println("localpart $lp")

    scatter_data = nothing
    if myid() == 1
        scatter_data = rand(Int8, nprocs()*2)
        println("scattering $scatter_data")
    end
    lp = scatter(scatter_data, 1, tag=2)
    println("localpart $lp")

    gathered_data = gather(myid(), 1, tag=3)
    if myid() == 1
        println("gather $gathered_data")
    end

    gathered_data = gather([myid(), myid()], 1, tag=4)
    if myid() == 1
        println("gather $gathered_data")
    end

end


