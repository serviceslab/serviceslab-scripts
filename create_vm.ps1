#create_vm.ps1
#Install-Module -Name vmware.powercli -Force
#Set-PowerCLIConfiguration -Scope User -ParticipateInCEIP $false -Confirm:$false
#increase timeout
Set-PowerCLIConfiguration -WebOperationTimeoutSeconds 1800 -Scope Session -Confirm:$false
Set-PowerCLIConfiguration -InvalidCertificateAction Ignore -Confirm:$false
Connect-VIServer -Server $hypervisor_host -User $hypervisor_user -Password $hypervisor_password
$vm_location=Get-Folder $vm_folder -ErrorAction SilentlyContinue -ErrorVariable NoFolder | Where-Object {$_.Parent.Name -eq $vm_parent_folder}
$vm_template_obj=Get-Template $vm_template
$vm_hostname="$hostname_prefix.$app.$domain"
Write-Host "$vm_hostname"
Write-Host "Launching VM..."
$vm_host = Get-VMHost -State Connected | Get-Random
if ($vm_host -eq "172.22.91.13") { $vm_host = "172.22.91.12" }
$vm=New-VM -Template $vm_template_obj -Name $vm_hostname -Location (Get-Folder -Id $vm_location.Id) -VMHost $vm_host -Datastore (Get-Datastore -RelatedObject $vm_host | Where-Object { $_.Name -like "*support*" -or $_.Name -like "*ssd1*" } | Get-Random)
Write-Host "VM created."
Start-Sleep 20
Set-VM $vm -MemoryGB $vm_memory_gb -NumCpu $vm_cores -Confirm:$false
Start-Sleep 10
Write-Host "Starting VM..."
Start-VM $vm
#while loop until boots and gets an ip
while ($null -eq $vm_ip){
    $vm_ip = Get-VM $vm | ForEach-Object{$_.Guest.IPAddress} | Where-Object{$_ -like "*.*"}
    Start-Sleep 10}
Write-Host "VM started."
Write-Output $vm_ip > "$($ENV:BUILD_TAG)-vm_ip.txt"
Write-Output $vm_hostname > "$($ENV:BUILD_TAG)-vm_hostname.txt"