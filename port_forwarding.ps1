$remoteport = bash.exe -c "ip addr show eth0 | grep 'inet '"
$found = $remoteport -match '\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}';

if ($found) {
  $remoteport = $matches[0];
} else {
  echo "The Script Exited, the ip address of WSL 2 cannot be found";
  exit;
}

#[Ports]
#Prompt the user to enter comma-separated ports
$ports = Read-Host -Prompt "Enter the ports you want to forward (comma-separated)"
$ports = $ports.Split(',') | ForEach-Object { $_.Trim() }

#[Static ip]
#You can change the addr to your ip config to listen to a specific address
$addr = '0.0.0.0';
$ports_a = $ports -join ",";

#Remove existing firewall rules and group
$existingRules = Get-NetFirewallRule -DisplayGroup "WSL 2 Firewall Unlock" -ErrorAction SilentlyContinue
if ($existingRules) {
  $existingRules | Remove-NetFirewallRule
  Remove-NetFirewallRule -DisplayGroup "WSL 2 Firewall Unlock" -ErrorAction SilentlyContinue
}

#Remove firewall rules for ports not in the list
$existingRules = Get-NetFirewallRule -DisplayName "WSL 2 Firewall Unlock*"
foreach ($rule in $existingRules) {
  $rulePort = $rule.LocalPorts
  if ($ports -notcontains $rulePort) {
    Remove-NetFirewallRule -DisplayName $rule.DisplayName
  }
}

#Create a new firewall rule group
New-NetFirewallRule -DisplayName "WSL 2 Firewall Unlock" -Direction Outbound -LocalPort Any -Action Allow -Protocol TCP -Profile Any -Group "WSL 2 Firewall Unlock"
New-NetFirewallRule -DisplayName "WSL 2 Firewall Unlock" -Direction Inbound -LocalPort Any -Action Allow -Protocol TCP -Profile Any -Group "WSL 2 Firewall Unlock"

#Adding Exception Rules for inbound and outbound Rules for all profiles
foreach ($port in $ports) {
  New-NetFirewallRule -DisplayName "WSL 2 Firewall Unlock $port" -Direction Outbound -LocalPort $port -Action Allow -Protocol TCP -Profile Any -Group "WSL 2 Firewall Unlock"
  New-NetFirewallRule -DisplayName "WSL 2 Firewall Unlock $port" -Direction Inbound -LocalPort $port -Action Allow -Protocol TCP -Profile Any -Group "WSL 2 Firewall Unlock"
}

#Remove all existing port forwarding rules
iex "netsh interface portproxy reset"

#Configure port forwarding using netsh
foreach ($port in $ports) {
  iex "netsh interface portproxy add v4tov4 listenport=$port listenaddress=$addr connectport=$port connectaddress=$remoteport";
}