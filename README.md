# Monero Tor .onion service on Tails

A quick and dirty script to create Tor .onion services on Tails.

## About

Create, backup and restore Tor .onion services in seconds on Tails. By default it will create an onion service for a Monero RPC daemon. This will allow remote Monero clients to quickly sync wallets without storing the entire blockchain. All they have to do is point the wallet to the .onion hostname.

When the 'Persistent' directory is available the script will automatically create a backup of the .onion service. The script also has the option to restore .onion service(s) from the Persistent directory after a reboot.

There is support for so called 'stealth' onion services. This will create a Tor .onion service that requires client side authentication before a connection can be created. This is useful when you want to keep your onion service private.

The script can also create .onion services for a Monero P2P server and SSH server.

## Download the script

Download the Monero onion script:

        git clone https://github.com/garlicgambit/monero-onion
        cd monero-onion

**Important:** Every time you boot Tails you need to load the script. It might be a good idea to store it in a persistent directory so you don't need to download it after each reboot.

## How to use the script

Create a .onion service for a Monero RPC server (default action):

        sudo ./onion-service.sh

Create a .onion service for a Monero P2P block synchronization server:

        sudo ./onion-service.sh -m

Create a .onion service for a SSH server (useful for remote administration):

        sudo ./onion-service.sh -s

Use the -t option to create a 'stealth' .onion service. This is useful when you want to keep the .onion service private. You will need to add the authorization code to the Tor configuration on the client. You do this with the 'HidServAuth' option. This example will create a stealth .onion for a Monero RPC service:

        sudo ./onion-service.sh -t

Create a stealth .onion service for SSH:

        sudo ./onion-service.sh -t -s

Use the -r option to restore a .onion service. Use this after a reboot of Tails. This example will restore a Monero RPC onion service:

        sudo ./onion-service.sh -r

Use the -p option to disable the automatic backup of the .onion service to the 'Persistent' directory:

        sudo ./onion-service.sh -p

Use the -b option to create a manual backup of the .onion service to the 'Persistent' directory:

        sudo ./onion-service.sh -b

Use the -h option to display all options:

        sudo ./onion-service.sh -h

## Examples with output

Create a regular Tor .onion service for a Monero RPC server (default action):

        sudo ./onion-service.sh
        Cooking onions... please wait
        WARNING: A persistent backup of the Tor onion service for monero is created at:
        /home/amnesia/Persistent/tor/onion_services/monero_rpc
        
        You can use this backup to restore the onion service.
        
        The .onion name for the monero service is:
        e7kkhtgrufwcyjko.onion

In this example you would need to configure the remote wallet to connect to: `e7kkhtgrufwcyjko.onion`.

Create a stealth Tor .onion service for a Monero RPC server:

        sudo ./onion-service.sh -t
        Cooking onions... please wait
        WARNING: A persistent backup of the Tor onion service for monero is created at:
        /home/amnesia/Persistent/tor/onion_services/monero_rpc
        
        You can use this backup to restore the onion service.
        
        The .onion name for the monero service is:
        rsjplnys9sl7ykf3.onion vAZaU75Wh7naPkj41CG7sR # client: monero_1

In this example you would need to add `HidServAuth vAZaU75Wh7naPkj41CG7sR` to the Tor configuration on the remote client. And configure the remote wallet to connect to: `rsjplnys9sl7ykf3.onion`.

## How to use Tor .onion service in combination with the Monero daemon

Start a Monero daemon that opens the RPC port for the .onion service and local wallets:

        DNS_PUBLIC=tcp torsocks ./monerod --p2p-bind-ip 127.0.0.1 --no-igd --rpc-bind-ip 127.0.0.1 --data-dir /home/amnesia/Persistent/your/directory/to/the/blockchain

Or start a Monero daemon that opens the RPC port for the .onion service, local wallets and LAN clients:

        DNS_PUBLIC=tcp TORSOCKS_ALLOW_INBOUND=1 torsocks ./monerod --p2p-bind-ip 127.0.0.1 --no-igd --rpc-bind-ip 0.0.0.0 --confirm-external-bind --data-dir /home/amnesia/Persistent/your/directory/to/the/blockchain

**Important:** Add the `--restricted-rpc` option to only allow view only commands on the Monero RPC daemon. This is useful when you run a public RPC daemon and don't want clients to remotely manage certain options. It will disable access to options like mining, shutting down the RPC daemon and more.

## Firewall rules

Optional: Allow local wallets on the Tails system to access the RPC service:

        sudo iptables -I OUTPUT 3 -d 127.0.0.1 -o lo -p tcp --dport 18081 --syn -m owner --uid-owner amnesia -j ACCEPT

Optional: Allow clients on the LAN network to access the RPC service with the following permissive firewall rules:

        sudo iptables -A INPUT -p tcp -s 10.0.0.0/8 --syn --dport 18081 -j ACCEPT
        sudo iptables -A INPUT -p tcp -s 172.16.0.0/12 --syn --dport 18081 -j ACCEPT
        sudo iptables -A INPUT -p tcp -s 192.168.0.0/16 --syn --dport 18081 -j ACCEPT

Optional: A stricter firewall rule for clients on the LAN network. Only allow source IP 10.0.0.2 (client) to access the RPC service:

        sudo iptables -A INPUT -p tcp -s 10.0.0.2 --syn --dport 18081 -j ACCEPT

## How to connect a Monero client to a Tor .onion service

Monero wallet CLI:

        torsocks ./monero-wallet-cli --daemon-host ONIONHOSTNAME.onion

Example:

        torsocks ./monero-wallet-cli --daemon-host e7kkhtgrufwcyjko.onion

Monero wallet GUI:

        torsocks ./monero-wallet-gui

If you open the GUI for the first time you need to set the daemon address from 'localhost' to the .onion hostname. On the first screen you select your preferred language. The second screen allows you to set the '_Custom daemon address_'. You need to add the full .onion address. Example: e7kkhtgrufwcyjko.onion:18081

You can also change the address via the '_Settings_' tab. Configure the .onion address in '_Daemon address_' and click on '_Connect_' to start the connection to the .onion daemon.

## License

MIT

## Donate

Support this project and send a donation to:

Monero: `463DQj1ebHSWrsyuFTfHSTDaACx3WZtmMFMwb6QEX7asGyUBaRe2fHbhMchpZnaQ6XKXcHZLq8Vt1BRSLpbqdr283QinCRK`

Bitcoin: `183x37Wc3jfduKGa5umqHt2gW7tgqWcbWh`

## Support

Website: [garlicgambit.wordpress.com](https://garlicgambit.wordpress.com)
