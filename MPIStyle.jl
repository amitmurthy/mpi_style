module MPIStyle

const map_worker_channels = Dict{Int, RemoteChannel}()
const my_c = RemoteChannel(()->Channel(typemax(Int)))
map_worker_channels[myid()] = my_c

const sorted_procs = sort(procs())
const sorted_workers = sort(workers())

init_comm_channels() = @everywhere MPIStyle.channel_sendrecv()

# higher pids send their channels to lower pids. Get channels from the lower pid in return.
function channel_sendrecv()
    pididx = findfirst(sorted_procs, myid())
    @sync for p in sorted_procs[1:pididx-1]
        @async map_worker_channels[p] = remotecall_fetch((from,c) -> begin
                map_worker_channels[from] = c
                map_worker_channels[myid()]
            end, p, myid(), my_c)
    end
end

function sendto(pid, data)
    #println("sending to $pid")
    @async put!(map_worker_channels[pid], (myid(), data))
end

function recvfrom_(pid)
    try
        from, data = take!(map_worker_channels[myid()])
        #println("Got $from $data")
        @assert from == pid
        return data
    catch e
        println(STDERR, e)
        rethrow(e)
    end
end

function recvfrom_any()
    try
        from, data = take!(map_worker_channels[myid()])
        #println("Got $from $data")
        return (from,data)
    catch e
        println(STDERR, e)
        rethrow(e)
    end
end

function barrier()
    try
        # send a message to everyone
        for p in sorted_procs
            sendto(p, (myid(),nothing))
        end
        # make sure we recv a message from everyone
        pending=deepcopy(sorted_procs)
        while length(pending) > 0
            from, _ = take!(map_worker_channels[myid()])
            filter!(x->x!=from, pending)
        end
        return nothing
    catch e
        println(STDERR, e)
        rethrow(e)
    end
end

function bcast(x, from)
    if myid() == from
        for p in filter(x->x!=from, sorted_procs)
            sendto(p, x)
        end
        return x
    else
        #println("waiting to recv from $from")
        x = recvfrom_(from)
        return x
    end
end

function scatter(x, from)
    if myid() == from
        @assert rem(length(x), length(sorted_procs)) == 0
        cnt = div(length(x), length(sorted_procs))
        for (i,p) in enumerate(sorted_procs)
            p == from && continue
            sendto(p, x[cnt*(i-1)+1:cnt*i])
        end
        myidx = findfirst(sorted_procs, from)
        return x[cnt*(myidx-1)+1:cnt*myidx]
    else
        return recvfrom_(from)
    end
end

function gather(x, to)
    if myid() == to
        gathered_data = Array{Any}(length(sorted_procs))
        myidx = findfirst(sorted_procs, to)
        gathered_data[myidx] = x
        n = length(sorted_procs) - 1
        while n > 0
            from, data_x = recvfrom_any()
            fromidx = findfirst(sorted_procs, from)
            gathered_data[fromidx] = data_x
            n=n-1
        end
        return gathered_data
    else
        sendto(to, x)
        return x
    end
end

export init_comm_channels, sendto, recvfrom_, barrier, bcast, scatter, gather

end

