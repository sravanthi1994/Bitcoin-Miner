defmodule Main do
  def main(args) do
    {_,input, _} = OptionParser.parse(args)
    if length(input)!=1 do #Check only 1 argument is passed in command line
      throw("More than 1 command line argument")
      exit(0)
    end
#as input for the client contains ip address, the command can be easily identified by .
    if(String.contains?(List.to_string(input), ".")) do
      input = "scharugu@" <> List.to_string(input)
      Worker.createprocesses(input)
    else
      {:ok, ifs} = :inet.getif()
      ip_adds = Enum.map(ifs, fn {ip, _broadaddr, _mask} -> ip end)
      [ipaddress | _] = Enum.filter(Enum.map(ip_adds, fn x -> to_string(:inet.ntoa(x)) end), fn x -> "127.0.0.1" != x end)
      ip = "scharugu@" <> ipaddress
      IO.inspect(ip)
      IO.inspect(Node.start(:"#{ip}"))#this is the IP of the machine on which you run the code
      IO.inspect(Node.set_cookie :srav)
      Server.start(List.to_string(input))
    end
  end
end  

defmodule Server do
  @name :server
  @count 1
  @length 15
  @ufid "scharugu;"
  

  def start(input) do
    pid = spawn(__MODULE__, :mining, [self()])
    :global.register_name(@name,pid)
    IO.inspect(pid)
    allocator(input)
    Worker.keepAlive()
  end
#mining done by the server
  def mining(serverPid) do
    Worker.serverWork(serverPid)
  end

#allocator generates random strings and send to the clients
#allocator also receives the hashed strings and print the output
  def allocator(input) do
    receive do
      {:ready, pid} -> 
        list = generate_random_strings(@count)
        send pid, {:ok, list, pid, input}
      {:answer, pid, bitcoins} ->
        Enum.each(bitcoins, fn(coin) -> IO.puts elem(coin,0)<> "\t" <> elem(coin,1) end)
        list = generate_random_strings(@count)
        send pid, {:ok, list, pid,input}
    end  
    allocator(input)  
  end

  def generate_random_strings(count) do
    Enum.map(1..count, fn(_x) -> random_string() end)
  end
  
  def random_string do
    @ufid <> (:crypto.strong_rand_bytes(@length) |> Base.url_encode64 |> binary_part(0, @length) )
  end

end

defmodule Worker do
  #@name :server
  def serverWork(serverPid) do
      numberOfProcessors = :erlang.system_info(:logical_processors) #calculate number of cores on the machine
      for _x <- 1..100*numberOfProcessors do
        spawnprocess(serverPid) #initialize the workers
      end
    end
  
  def wait(sname) do
    :global.sync()
    if sname == :undefined do 
        # IO.inspect(:global.whereis_name(@name))
        wait(:global.whereis_name(:server))
    end
  end
  def createprocesses(input) do
    {:ok, ifs} = :inet.getif()
    ip_adds = Enum.map(ifs, fn {ip, _broadaddr, _mask} -> ip end)
    [ipaddress | _] = Enum.filter(Enum.map(ip_adds, fn x -> to_string(:inet.ntoa(x)) end),fn x -> "127.0.0.1" != x end)
    ip = "worker" <> "#{:rand.uniform(100)}@" <> ipaddress
    IO.inspect(ip)
    Node.start(:"#{ip}")#this is the IP of the machine on which you run the code
    Node.set_cookie :srav
    IO.inspect (input)
    IO.inspect(Node.connect(:"#{input}"))
    #IO.inspect(:global.whereis_name(:server))
    wait(:global.whereis_name(:server))  #waiting for server pid 
    #IO.puts(~s{"Updated :#{inspect :global.whereis_name(:server)}"})
    serverPid =  :global.whereis_name(:server)  
    #IO.inspect(serverPid)                    
    no_of_processors = :erlang.system_info(:logical_processors) 
    for _x <- 1..3*no_of_processors do
      spawnprocess(serverPid)
    end
    keepAlive(input)
  end

  #when a client starts, it starts no.of processes based on no.of cores

  def spawnprocess(serverPid) do
    #IO.puts("Reacived")
    #IO.inspect(serverPid)
    clientPid = spawn(__MODULE__, :miner, [serverPid]) 
    #IO.inspect(clientPid)
    send serverPid, {:ready, clientPid}
  end
  
  def keepAlive(serverIp) do
    if false == Node.connect(:"#{serverIp}") do
        IO.puts("server exited")
       exit(0)# checking for server status
    end
    keepAlive(serverIp)
  end

  def miner(serverPid) do
    receive do
      {:ok, list, pid, input} -> 
        bitcoins = get_valid_bitcoins(list, String.to_integer(input))#FIX HARD CODING
        #IO.inspect(list)
        send serverPid, {:answer, pid, bitcoins}
    end
        miner(serverPid)
  end

  def get_valid_bitcoins(string_list, zero_count) do
    Enum.map(string_list, fn(x) -> {x, sha256(x)} end )
    |> Enum.filter(fn(bitcoin) ->  String.starts_with?(elem(bitcoin, 1), String.duplicate("0", zero_count)) end) 
  end

  def sha256(str) do
    Base.encode16(:crypto.hash(:sha256, str))
  end
end