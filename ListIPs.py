import ipaddress
import csv

def list_ips_in_network():
    # Get input from the user for multiple subnets
    input_subnets = input("Enter IP addresses with subnet masks separated by commas (e.g., 192.168.1.0/24,10.0.0.0/8): ")
    subnets = [subnet.strip() for subnet in input_subnets.split(',')]

    try:
        # List all IPs in the provided subnets
        all_ips = []
        for subnet_str in subnets:
            network = ipaddress.IPv4Network(subnet_str, strict=False)
            all_ips.extend([str(ip) for ip in network.hosts()])

        # Write the IPs to a CSV file
        with open('IPs.csv', 'w', newline='') as csvfile:
            csv_writer = csv.writer(csvfile)
            csv_writer.writerow(['IPs in the networks'])
            csv_writer.writerows(map(lambda x: [x], all_ips))

        print(f"\nIPs in the provided networks have been written to IPs.csv.")

    except ValueError as e:
        print(f"Error: {e}")

if __name__ == "__main__":
    list_ips_in_network()
