# Bitcoin-Miner

A distributed bitcoin mining system that can run on multiple cores. Server is running many clients and a client can be joined at any point of time. Random strings are generated at the server and sent to the clients. Client then uses SHA-256 in order to hash the string and check for number of zeroes in the beginning of the hashed string. If this is the desired number, it sends to the server and server displays it.
This is a project in elixir which employs actor model.
