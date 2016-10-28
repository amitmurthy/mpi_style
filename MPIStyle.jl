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
                my_c
            end, p, myid(), my_c)
    end
end

function send_msg(to, typ, data)
    #println("sending ($typ, $data) to $to")
    @async put!(map_worker_channels[to], (typ, myid(), data))
end

function get_msg(typ_in, from_in=false)
    unexpected_msgs=[]
    while true
        typ, from, data = take!(my_c)
        if (from_in != false && from_in != from) || (typ != typ_in)
            push!(unexpected_msgs, (typ, from, data))
        else
            #println("got ($typ_in, $data) from $from")
            # put all the messages we read (but not expected) back to the channel
            foreach(x->put!(my_c, x), unexpected_msgs)
            return (from, data)
        end
    end
end

sendto(pid, data) = send_msg(pid, :sendto, data)

function recvfrom_(pid)
    _, data = get_msg(:sendto, pid)
    return data
end

function recvfrom_any()
    from, data = get_msg(:sendto, false)
    return (from,data)
end

function barrier()
    # send a message to everyone
    for p in sorted_procs
        send_msg(p, :barrier, nothing)
    end
    # make sure we recv a message from everyone
    pending=deepcopy(sorted_procs)
    while length(pending) > 0
        from, _ = get_msg(:barrier, false)
        filter!(x->x!=from, pending)
    end
    return nothing
end

function bcast(data, pid)
    if myid() == pid
        for p in filter(x->x!=pid, sorted_procs)
            send_msg(p, :bcast, data)
        end
        return data
    else
        #println("waiting to recv from $pid")
        from, data = get_msg(:bcast, pid)
        return data
    end
end

function scatter(x, pid)
    if myid() == pid
        @assert rem(length(x), length(sorted_procs)) == 0
        cnt = div(length(x), length(sorted_procs))
        for (i,p) in enumerate(sorted_procs)
            p == pid && continue
            send_msg(p, :scatter, x[cnt*(i-1)+1:cnt*i])
        end
        myidx = findfirst(sorted_procs, pid)
        return x[cnt*(myidx-1)+1:cnt*myidx]
    else
        _, data = get_msg(:scatter, pid)
        return data
    end
end

function gather(x, pid)
    if myid() == pid
        gathered_data = Array{Any}(length(sorted_procs))
        myidx = findfirst(sorted_procs, pid)
        gathered_data[myidx] = x
        n = length(sorted_procs) - 1
        while n > 0
            from, data_x = get_msg(:gather, false)
            fromidx = findfirst(sorted_procs, from)
            gathered_data[fromidx] = data_x
            n=n-1
        end
        return gathered_data
    else
        send_msg(pid, :gather, x)
        return x
    end
end

export init_comm_channels, sendto, recvfrom_, barrier, bcast, scatter, gather

end

